#!/bin/sh
# Usage: php-brotli-levels.sh <repo> <PHP package folder>
# Tars the folder in memory and reports the brotli-compressed size, compression time and
# decompression time at several quality levels (window 24), with the repo's node-tar.
cd "$1" && node --input-type=module - "$2" <<'JS'
import fs from 'node:fs';
import zlib from 'node:zlib';
import * as tar from 'tar';

const dir = process.argv[ 2 ];
const chunks = [];
const stream = tar.c( { cwd: dir, portable: true, sync: true }, fs.readdirSync( dir ) );
let chunk;
while ( ( chunk = stream.read() ) !== null ) {
	chunks.push( chunk );
}
const tarball = Buffer.concat( chunks );
console.log( `tar bytes=${ tarball.length }` );
for ( const quality of [ 9, 10, 11 ] ) {
	let start = process.hrtime.bigint();
	const compressed = zlib.brotliCompressSync( tarball, {
		params: {
			[ zlib.constants.BROTLI_PARAM_QUALITY ]: quality,
			[ zlib.constants.BROTLI_PARAM_LGWIN ]: 24,
			[ zlib.constants.BROTLI_PARAM_SIZE_HINT ]: tarball.length,
		},
	} );
	const compressMs = Number( process.hrtime.bigint() - start ) / 1e6;
	start = process.hrtime.bigint();
	zlib.brotliDecompressSync( compressed );
	const decompressMs = Number( process.hrtime.bigint() - start ) / 1e6;
	console.log(
		`quality=${ quality } lgwin=24 bytes=${ compressed.length } compress=${ ( compressMs / 1000 ).toFixed(
			1
		) }s decompress=${ decompressMs.toFixed( 0 ) }ms`
	);
}
JS
