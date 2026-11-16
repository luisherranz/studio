/// <reference types="vite/client" />
import type { ProviderConfigs, ProviderId, ProviderSite } from './registry';
import type { ProviderServices } from './types';

// Every provider folder's services, which its `services.ts` exports as `services`.
const SERVICES = Object.values(
	import.meta.glob< ProviderServices >( './*/services.ts', { eager: true, import: 'services' } )
);

export function getProviderServices< Id extends ProviderId >(
	id: Id
): ProviderServices< ProviderConfigs[ Id ], ProviderSite< Id > > {
	const services = SERVICES.find( ( candidate ) => candidate.id === id );
	if ( ! services ) {
		throw new Error(
			`The ${ id } provider has no services: its folder's services.ts exports them as \`services\`, from defineServices().`
		);
	}
	return services as ProviderServices< ProviderConfigs[ Id ], ProviderSite< Id > >;
}

// Previews upload to WordPress.com the way a push does, until they are a capability of their own.
export { createTusUpload } from './wpcom/sites/upload';
