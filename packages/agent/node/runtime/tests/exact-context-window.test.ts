import fs from 'fs';
import os from 'os';
import path from 'path';
import { SessionManager, type AgentSessionEvent } from '@earendil-works/pi-coding-agent';
import { getProviderServices } from '@studio/providers/services';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { createAgent } from '@studio/agent/node/agent';
import { getAgentEndFailure } from '@studio/agent/protocol/errors';
import { createFakeHost } from '../../tests/fake-host';

const roots = vi.hoisted( () => ( { config: '' } ) );

vi.mock( '@studio/common/lib/well-known-paths', async ( importOriginal ) => {
	const actual = await importOriginal< typeof import('@studio/common/lib/well-known-paths') >();
	return {
		...actual,
		getConfigDirectory: () => roots.config,
		getAiPayloadsPath: () => path.join( roots.config, 'ai-payloads' ),
	};
} );

const SERVER = 'http://127.0.0.1:8080';

function sse( reply: string ): Response {
	const chunks = [
		{ choices: [ { index: 0, delta: { role: 'assistant', content: reply } } ] },
		{ choices: [ { index: 0, delta: {}, finish_reason: 'stop' } ] },
		{ choices: [], usage: { prompt_tokens: 100, completion_tokens: 5, total_tokens: 105 } },
	];
	const body = chunks.map( ( chunk ) => `data: ${ JSON.stringify( chunk ) }\n\n` ).join( '' );
	return new Response( `${ body }data: [DONE]\n\n`, {
		headers: { 'Content-Type': 'text/event-stream' },
	} );
}

describe( 'a connection whose context window is exact', () => {
	let sitesRoot: string;
	// The chat requests the server received, by their bodies.
	let requests: { messages: { content: unknown }[] }[];

	// A llama-server running `tiny` with a context of `context` tokens, which reports it.
	const serve = ( context?: number ) =>
		vi.spyOn( globalThis, 'fetch' ).mockImplementation( async ( input, init ) => {
			const url = String( input );
			if ( url === `${ SERVER }/v1/models` ) {
				return Response.json( {
					data: [
						{
							id: 'tiny',
							architecture: { input_modalities: [ 'text' ] },
							...( context ? { meta: { n_ctx: context } } : {} ),
						},
					],
				} );
			}
			if ( url === `${ SERVER }/v1/chat/completions` ) {
				const body = JSON.parse( String( init?.body ) );
				requests.push( body );
				const summarizing = JSON.stringify( body.messages ).includes( '<conversation>' );
				return sse( summarizing ? 'A summary of the earlier conversation.' : 'Hello there.' );
			}
			return new Response( 'Not found', { status: 404 } );
		} );

	async function runTurn( session: SessionManager ) {
		const ai = await getProviderServices( 'local-llm' ).ai!.model(
			{ method: 'server', baseUrl: `${ SERVER }/v1`, model: 'tiny' },
			'local-llm/tiny',
			{}
		);
		const events: AgentSessionEvent[] = [];
		const agent = createAgent( { host: createFakeHost( sitesRoot ) } );
		await agent.runTurn( {
			prompt: 'Add a page about us.',
			session,
			ai,
			onEvent: ( event ) => events.push( event ),
		} ).result;
		return events.filter( ( event ) => event.type === 'agent_end' && ! event.willRetry ).at( -1 )!;
	}

	beforeEach( () => {
		requests = [];
		sitesRoot = fs.mkdtempSync( path.join( os.tmpdir(), 'studio-exact-window-' ) );
		roots.config = path.join( sitesRoot, 'config' );
	} );

	afterEach( () => {
		vi.restoreAllMocks();
		fs.rmSync( sitesRoot, { recursive: true, force: true } );
	} );

	it( 'never sends a turn the window can’t hold, and says the context is too small', async () => {
		serve( 4096 );

		const end = await runTurn( SessionManager.inMemory( sitesRoot ) );

		expect( requests ).toEqual( [] );
		expect( getAgentEndFailure( end )?.message ).toBe(
			'The context tiny runs with is too small for Studio Code. Raise its context length in your server’s settings.'
		);
	} );

	it( 'compacts a conversation that outgrows the window, and keeps replying', async () => {
		serve( 40_000 );
		const session = SessionManager.inMemory( sitesRoot );
		// Earlier turns of about 7,000 tokens each, by pi's estimate.
		for ( let turn = 0; turn < 4; turn++ ) {
			session.appendMessage( { role: 'user', content: 'x'.repeat( 24_000 ), timestamp: turn } );
			session.appendMessage( {
				role: 'assistant',
				content: [ { type: 'text', text: 'Done.' } ],
				api: 'openai-completions',
				provider: 'local-llm',
				model: 'local-llm/tiny',
				usage: {
					input: 0,
					output: 0,
					cacheRead: 0,
					cacheWrite: 0,
					totalTokens: 0,
					cost: { input: 0, output: 0, cacheRead: 0, cacheWrite: 0, total: 0 },
				},
				stopReason: 'stop',
				timestamp: turn,
			} );
		}

		const end = await runTurn( session );

		expect( getAgentEndFailure( end ) ).toBeNull();
		expect( session.getEntries().some( ( entry ) => entry.type === 'compaction' ) ).toBe( true );
		expect( JSON.stringify( requests.at( -1 )?.messages ) ).toContain(
			'A summary of the earlier conversation.'
		);
	} );

	it( 'leaves a server that doesn’t say its context to refuse what doesn’t fit', async () => {
		serve();

		const end = await runTurn( SessionManager.inMemory( sitesRoot ) );

		expect( getAgentEndFailure( end ) ).toBeNull();
		expect( requests ).toHaveLength( 1 );
	} );
} );
