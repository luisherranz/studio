import {
	AI_PROVIDER_IDS,
	ConnectError,
	DEFAULT_PROVIDER_ID,
	findAiModel,
	getConnectMethod,
	getProvider,
	normalizeProviderId,
	PROVIDER_IDS,
	servesAiModel,
	toStoredProviderId,
	type AccountDetails,
	type AiModelId,
	type AiProviderId,
	type ListedAiModel,
	type ProviderConfigs,
	type ProviderId,
	type ProviderServices,
} from '@studio/providers';
import {
	readAiFields,
	readFreshProviderConfig,
	readProviderConfig,
	updateAiFields,
	writeProviderConfig,
} from './provider-config';
import { receiveRedirect } from './provider-connect';
import {
	lockSharedConfig,
	readSharedConfig,
	saveSharedConfig,
	unlockSharedConfig,
} from './shared-config';

// A provider's account as surfaces show it; never the credential itself.
export type ProviderAccount = { connected: false } | ( { connected: true } & AccountDetails );

export interface AiSettings {
	// The chat provider new conversations use.
	provider: AiProviderId;
	accounts: Record< ProviderId, ProviderAccount >;
	// The model the user chose last on each provider whose models a server they run lists, which
	// new chats on it start on.
	chosenModels?: Partial< Record< ProviderId, AiModelId > >;
}

/** The saved chat provider, or undefined when none was ever chosen. */
export async function readSelectedAiProvider(): Promise< AiProviderId | undefined > {
	const { aiProvider } = await readAiFields();
	return aiProvider === undefined ? undefined : normalizeProviderId( aiProvider, AI_PROVIDER_IDS );
}

// What surfaces show of the provider's account, from its config.
export function describeAccount( id: ProviderId, config: unknown ): ProviderAccount {
	const { describe } = getProvider( id ).account as {
		describe: ( config: unknown ) => AccountDetails;
	};
	return config === undefined ? { connected: false } : { connected: true, ...describe( config ) };
}

async function readAccount( id: ProviderId ): Promise< ProviderAccount > {
	return describeAccount( id, await readProviderConfig( id ) );
}

async function readChosenModels(): Promise< NonNullable< AiSettings[ 'chosenModels' ] > > {
	const { chosenAiModels = {} } = await readSharedConfig();
	return Object.fromEntries(
		AI_PROVIDER_IDS.flatMap( ( id ) => {
			const model = chosenAiModels[ toStoredProviderId( id ) ];
			return model && servesAiModel( id, model ) ? [ [ id, model ] ] : [];
		} )
	);
}

export async function readAiSettings(): Promise< AiSettings > {
	const [ provider, chosenModels, ...accounts ] = await Promise.all( [
		readSelectedAiProvider(),
		readChosenModels(),
		...PROVIDER_IDS.map( readAccount ),
	] );
	return {
		provider: provider ?? DEFAULT_PROVIDER_ID,
		accounts: Object.fromEntries(
			PROVIDER_IDS.map( ( id, index ) => [ id, accounts[ index ] ] )
		) as AiSettings[ 'accounts' ],
		chosenModels,
	};
}

// Remembers `model` as the one new chats on the provider start on, or forgets it.
async function writeChosenModel( provider: ProviderId, model: AiModelId | undefined ) {
	const stored = toStoredProviderId( provider );
	if ( ( await readSharedConfig() ).chosenAiModels?.[ stored ] === model ) {
		return;
	}
	try {
		await lockSharedConfig();
		const shared = await readSharedConfig();
		const { [ stored ]: _removed, ...others } = shared.chosenAiModels ?? {};
		shared.chosenAiModels = model ? { ...others, [ stored ]: model } : others;
		if ( ! Object.keys( shared.chosenAiModels ).length ) {
			delete shared.chosenAiModels;
		}
		await saveSharedConfig( shared );
	} finally {
		await unlockSharedConfig();
	}
}

/**
 * Records that the user chose `model`, when a server they run lists it: new chats on its provider
 * start on it from then on. Other models leave the settings as they are.
 */
export async function recordAiModelChoice( model: string ): Promise< void > {
	const provider = findAiModel( model )?.provider;
	if ( provider && getProvider( provider ).ai?.userServer ) {
		await writeChosenModel( provider, model as AiModelId );
	}
}

/**
 * The models a provider's server lists now, read with its stored config, given the provider's
 * services from `@studio/providers/services`. Throws, with the words for it, when the server
 * doesn't answer.
 */
export async function listProviderModels< Config >(
	services: ProviderServices< Config >
): Promise< ListedAiModel[] > {
	const listModels = services.ai?.listModels;
	if ( ! listModels ) {
		throw new Error( `${ getProvider( services.id ).label } doesn't list models from a server.` );
	}
	return listModels( await readFreshProviderConfig( services ) );
}

/** Persists the provider without validation — for flows that already ran it. */
export async function persistSelectedAiProvider( provider: AiProviderId ): Promise< void > {
	await updateAiFields( { aiProvider: toStoredProviderId( provider ) } );
}

/**
 * Connects the provider (from `@studio/providers/services`) with `method` and what the user
 * gave: a form's values, or the handoff of the connection `startProviderConnect` started, which a
 * loopback sign-in completes with its redirect. The provider checks them, and its config is
 * stored only when it accepts them. Studio forgets the model the user chose on it, which a server
 * connected anew may not have.
 */
export async function connectProvider< Config >(
	services: ProviderServices< Config >,
	method: string,
	input: Record< string, string >,
	options: { pasteUrl?: () => Promise< string > } = {}
): Promise< AiSettings > {
	const { id } = services;
	const config = await services.account.connect(
		method,
		getConnectMethod( id, method ).kind === 'loopback'
			? await receiveRedirect( id, input, options.pasteUrl )
			: input
	);
	await writeProviderConfig( id, config as ProviderConfigs[ ProviderId ] );
	await writeChosenModel( id, undefined );
	// A chat provider becomes the default only when the current default can't be used, so
	// connecting another provider never takes over from a connected WordPress.com.
	const aiProvider = normalizeProviderId( id, AI_PROVIDER_IDS );
	const selected = ( await readSelectedAiProvider() ) ?? DEFAULT_PROVIDER_ID;
	if ( aiProvider && aiProvider !== selected && ! ( await readProviderConfig( selected ) ) ) {
		await persistSelectedAiProvider( aiProvider );
	}
	return readAiSettings();
}

/**
 * Removes the provider's config, after letting it clean up on its side, and the model the user
 * chose on it. A selected provider that is no longer connected falls back to WordPress.com.
 */
export async function disconnectProvider< Config >(
	services: ProviderServices< Config >
): Promise< AiSettings > {
	const { id } = services;
	const config = await readProviderConfig( id );
	if ( config ) {
		// Best-effort: disconnecting offline still forgets the account here.
		await services.account.disconnect?.( config as Config ).catch( () => undefined );
	}
	await writeProviderConfig( id, undefined );
	await writeChosenModel( id, undefined );
	if ( ( await readSelectedAiProvider() ) === id ) {
		await persistSelectedAiProvider( DEFAULT_PROVIDER_ID );
	}
	return readAiSettings();
}

/**
 * Selects the provider for new conversations, once it is connected. Existing
 * sessions keep the provider recorded in their session context.
 */
export async function setAiProvider( provider: AiProviderId ): Promise< AiSettings > {
	if ( ! ( await readProviderConfig( provider ) ) ) {
		throw new ConnectError( `Connect ${ getProvider( provider ).label } first.` );
	}
	await persistSelectedAiProvider( provider );
	return readAiSettings();
}
