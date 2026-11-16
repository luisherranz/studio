// Prints, for each Electron runtime locale, the Studio locale that
// apps/studio/src/lib/locale-node.ts getSupportedLocale() would pick when
// app.getLocale() returns it. Usage: node locale-match.mjs <repo> <locale...>
import { createRequire } from 'node:module';
import path from 'node:path';
import fs from 'node:fs';

const repo = process.argv[ 2 ];
const locales = process.argv.slice( 3 );
const require = createRequire( path.join( repo, 'apps/studio/package.json' ) );
const { match } = require( '@formatjs/intl-localematcher' );
const src = fs.readFileSync( path.join( repo, 'packages/common/lib/locale.ts' ), 'utf8' );
const block = src.slice( src.indexOf( 'supportedLocaleNames' ), src.indexOf( '};', src.indexOf( 'supportedLocaleNames' ) ) );
const supported = [ ...block.matchAll( /^\s*'?([a-z]{2,3}(?:-[a-z]{2})?)'?\s*:/gm ) ].map( ( m ) => m[ 1 ] );
console.log( 'supportedLocales:', supported.join( ' ' ) );
const mapped = [];
for ( const l of locales ) {
	let r;
	try {
		r = match( [ l ], supported, 'en' ).toLowerCase();
	} catch ( e ) {
		console.log( `${ JSON.stringify( l ) } -> error ${ e.message }` );
		continue;
	}
	console.log( `${ l } -> ${ r }` );
	if ( r !== 'en' ) mapped.push( l );
}
console.log( 'Electron locales mapped to a Studio translation:', mapped.join( ' ' ) );
