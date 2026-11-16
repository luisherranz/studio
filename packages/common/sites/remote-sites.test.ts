import fs from 'fs';
import os from 'os';
import path from 'path';
import { NotConnectedError, type ProviderServices } from '@studio/providers';
import { afterEach, beforeEach, expect, it, vi } from 'vitest';
import { listAccountSites } from './remote-sites';

let configDir: string;
const readShared = () =>
	JSON.parse( fs.readFileSync( path.join( configDir, 'shared.json' ), 'utf8' ) );

// Spacefast's services, standing in for a hosting provider whose credential expires and renews.
function renewingProvider( refresh: ( config: unknown ) => Promise< unknown > ) {
	const list = vi.fn( async () => [] );
	const provider = {
		id: 'spacefast',
		account: { connect: vi.fn(), refresh },
		sites: { list, push: vi.fn() },
	} as unknown as ProviderServices< { apiKey: string }, never > & { id: 'spacefast' };
	return { list, provider };
}

beforeEach( () => {
	configDir = fs.mkdtempSync( path.join( os.tmpdir(), 'studio-remote-sites-' ) );
	vi.stubEnv( 'DEV_CONFIG_DIR', configDir );
	fs.writeFileSync(
		path.join( configDir, 'shared.json' ),
		JSON.stringify( {
			version: 1,
			providerConfigs: { spacefast: { apiKey: 'sfa_old', expiresAt: null } },
		} )
	);
} );

afterEach( () => {
	vi.unstubAllEnvs();
	fs.rmSync( configDir, { recursive: true, force: true } );
} );

it( 'renews the credential before listing the account’s sites, and stores it', async () => {
	const { provider, list } = renewingProvider( async () => ( {
		apiKey: 'sfa_new',
		expiresAt: null,
	} ) );

	await listAccountSites( provider );

	expect( list ).toHaveBeenCalledWith( { apiKey: 'sfa_new', expiresAt: null }, expect.anything() );
	expect( readShared().providerConfigs.spacefast.apiKey ).toBe( 'sfa_new' );
} );

it( 'disconnects the provider when it no longer renews the credential', async () => {
	const { provider, list } = renewingProvider( () =>
		Promise.reject( new NotConnectedError( 'Connect again' ) )
	);

	await expect( listAccountSites( provider ) ).rejects.toThrow( 'Connect again' );

	expect( list ).not.toHaveBeenCalled();
	expect( readShared().providerConfigs ).toBeUndefined();
} );
