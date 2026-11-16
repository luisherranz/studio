import { __, sprintf } from '@wordpress/i18n';
import { ConnectError } from '../errors';
import { localLlmConnectInput } from './descriptor';
import { fetchModelEntries, readModelFacts, RefusedKeyError, toApiBase } from './server';
import type { LocalLlmConfig } from './config';
import type { ProviderServices } from '../types';

const getUnreachableMessage = ( address: string ) =>
	sprintf(
		/* translators: %s: the address of the user's model server, such as http://localhost:11434 */
		__( 'No local server answered at %s. Check the address, and that your server is running.' ),
		address
	);

export const getRefusedKeyMessage = () =>
	__( 'The local server refused the API key. Check the key, and connect again.' );

// The model new chats start on: the first the server says can chat and call tools, else the
// first that can chat, else the first it lists, when it doesn't say.
async function proposeModel(
	baseUrl: string,
	apiKey: string | undefined,
	entries: { id: string }[]
): Promise< string > {
	const facts = await readModelFacts( baseUrl, apiKey, entries );
	const pick = ( test: ( index: number ) => boolean ) =>
		entries.find( ( _entry, index ) => test( index ) )?.id;
	return (
		pick( ( index ) => facts[ index ].chat !== false && facts[ index ].tools === true ) ??
		pick( ( index ) => facts[ index ].chat !== false ) ??
		entries[ 0 ].id
	);
}

type LocalLlmAccount = ProviderServices< LocalLlmConfig >[ 'account' ];

// Connects when the server at the address lists at least one model, sending the key only when
// there is one.
const connect: LocalLlmAccount[ 'connect' ] = async ( _method, input ) => {
	const parsed = localLlmConnectInput().safeParse( input );
	if ( ! parsed.success ) {
		throw new ConnectError( parsed.error.issues[ 0 ].message );
	}
	const { address, apiKey: key } = parsed.data;
	const apiKey = key || undefined;
	const baseUrl = toApiBase( address );
	if ( ! baseUrl ) {
		throw new ConnectError( getUnreachableMessage( address ) );
	}
	const entries = await fetchModelEntries( baseUrl, apiKey ).catch( ( error ) => {
		throw new ConnectError(
			error instanceof RefusedKeyError ? getRefusedKeyMessage() : getUnreachableMessage( address )
		);
	} );
	if ( ! entries.length ) {
		throw new ConnectError(
			__( 'The local server has no models yet. Add one to your server, then connect again.' )
		);
	}
	return {
		method: 'server',
		baseUrl,
		...( apiKey ? { apiKey } : {} ),
		model: await proposeModel( baseUrl, apiKey, entries ),
	};
};

export const localLlmAccount: LocalLlmAccount = { connect };
