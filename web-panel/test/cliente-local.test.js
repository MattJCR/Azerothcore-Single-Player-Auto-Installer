// SPDX-FileCopyrightText: 2026 The Azerothcore-Single-Player contributors
// SPDX-License-Identifier: AGPL-3.0-or-later
// Cliente web local (WEB-LOCAL): lectura del manifiesto, qué MPQ abre el cliente por su nombre, reparto entre lo que se lee del
// equipo y lo que se baja del servidor, y la búsqueda de Data a partir de la carpeta elegida.
import test from 'node:test';
import assert from 'node:assert/strict';
import { parseManifest, clientLoadsPatch, classifyLocal, findDataDirectory } from '../public/cliente-local.js';

const MANIFEST = parseManifest([
  'common.MPQ\t100\t1', 'patch.MPQ\t50\t1', 'patch-3.MPQ\t30\t1', 'custom.MPQ\t5\t1', 'wateralpha.MPQ\t2\t1',
  'esES/patch-esES-3.MPQ\t20\t1', 'esES/patch-esES-4.MPQ\t3\t1', 'enUS/patch-enUS-3.MPQ\t21\t1', '',
].join('\r\n'));

test('el manifiesto admite la columna de origen y trata todo lo demás como base', () => {
  const rows = parseManifest('a.MPQ\t1\t1\n# comentario\nb.MPQ\t2\t1\tservidor\nc.MPQ\t3\t1\tbase\n');
  assert.deepEqual(rows.map((row) => [row.path, row.size, row.origin]), [['a.MPQ', 1, 'base'], ['b.MPQ', 2, 'servidor'], ['c.MPQ', 3, 'base']]);
});

test('sólo se cargan por nombre los parches que el cliente enumera', () => {
  for (const name of ['patch-5.MPQ', 'patch-A.mpq', 'esES/patch-esES-5.MPQ', 'enUS/patch-enUS-9.MPQ']) assert.equal(clientLoadsPatch(name), true, name);
  for (const name of ['mimod.MPQ', 'patch-10.MPQ', 'esES/patch-enUS-5.MPQ', 'patch-esES-5.MPQ', 'patch.MPQ', 'esES/patch-esES.MPQ']) assert.equal(clientLoadsPatch(name), false, name);
});

test('un fichero base que está en la carpeta se usa aunque sea distinto; sólo lo que falta lo pone el servidor', () => {
  const result = classifyLocal([
    { path: 'common.MPQ', size: 100 }, { path: 'patch.MPQ', size: 49 }, { path: 'esES/patch-esES-3.MPQ', size: 20 },
  ], MANIFEST);
  assert.deepEqual(result.local.map((file) => file.path), ['common.MPQ', 'patch.MPQ', 'esES/patch-esES-3.MPQ']);   // patch.MPQ pesa 49 y el del servidor 50: da igual
  assert.equal('distintos' in result, false);
  assert.deepEqual(result.ausentes.map((row) => row.path).sort(), ['enUS/patch-enUS-3.MPQ', 'patch-3.MPQ']);
  assert.equal(result.bytesLocal, 169);
  assert.equal(result.bytesServidor, 30 + 21);
});

test('lo que es del servidor nunca se lee del equipo, ni aunque exista uno local con ese nombre', () => {
  const result = classifyLocal([
    { path: 'custom.MPQ', size: 999 }, { path: 'esES/patch-esES-4.MPQ', size: 3 }, { path: 'patch-esES-4.MPQ', size: 7 }, { path: 'WaterAlpha.mpq', size: 2 },
  ], MANIFEST);
  assert.deepEqual(result.reservados.map((file) => file.path).sort(), ['WaterAlpha.mpq', 'custom.MPQ', 'esES/patch-esES-4.MPQ', 'patch-esES-4.MPQ']);
  assert.equal(result.local.length, 0);
  assert.equal(result.custom.length, 0);
  // y los del servidor no cuentan como ausentes: vienen del servidor por diseño
  assert.ok(!result.ausentes.some((row) => /custom|wateralpha|esES-4/i.test(row.path)));
});

test('la columna de origen del manifiesto amplía los nombres reservados', () => {
  const manifest = parseManifest('common.MPQ\t100\t1\nextra.MPQ\t4\t1\tservidor\n');
  const result = classifyLocal([{ path: 'extra.MPQ', size: 4 }, { path: 'common.MPQ', size: 100 }], manifest);
  assert.deepEqual(result.reservados.map((file) => file.path), ['extra.MPQ']);
  assert.deepEqual(result.ausentes, []);
});

test('un MPQ propio se acepta y se marca si el cliente lo abriría', () => {
  const result = classifyLocal([
    { path: 'patch-5.MPQ', size: 9 }, { path: 'esES/patch-esES-5.MPQ', size: 8 }, { path: 'mimod.MPQ', size: 7 },
  ], MANIFEST);
  assert.deepEqual(result.custom.map((file) => [file.path, file.carga]), [['patch-5.MPQ', true], ['esES/patch-esES-5.MPQ', true], ['mimod.MPQ', false]]);
});

// Carpetas simuladas con la parte de la API de File System Access que usa findDataDirectory.
function fakeDir(name, children = {}) {
  return {
    name, kind: 'directory',
    async getFileHandle(child) { if (children[child]?.kind === 'file') return children[child]; const error = new Error('no'); error.name = 'NotFoundError'; throw error; },
    async getDirectoryHandle(child) { if (children[child]?.kind === 'directory') return children[child]; const error = new Error('no'); error.name = 'NotFoundError'; throw error; },
  };
}
const fakeFile = (name) => ({ name, kind: 'file' });

test('encuentra Data tanto si se elige la carpeta de Wow.exe como la propia Data', async () => {
  const data = fakeDir('Data', { 'common.MPQ': fakeFile('common.MPQ') });
  const root = fakeDir('WoW', { Data: data, 'Wow.exe': fakeFile('Wow.exe') });
  assert.deepEqual(await findDataDirectory(root), { data, raiz: root });
  assert.deepEqual(await findDataDirectory(data), { data, raiz: null });
  assert.equal(await findDataDirectory(fakeDir('Otra', { 'notas.txt': fakeFile('notas.txt') })), null);
});
