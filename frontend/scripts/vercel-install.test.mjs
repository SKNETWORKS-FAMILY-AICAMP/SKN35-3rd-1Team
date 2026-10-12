import {test} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';

test('a restored Flutter cache with missing or incomplete .git can build again and keeps downloaded artifacts', () => {
  const temporary = fs.mkdtempSync(path.join(os.tmpdir(), 'artlog-sdk-cache-'));
  try {
    const bin = path.join(temporary, 'bin');
    const sdk = path.join(temporary, 'sdk');
    const launcher = path.join(temporary, 'flutter-fixture');
    const log = path.join(temporary, 'commands.log');
    fs.mkdirSync(bin);
    fs.writeFileSync(launcher, `#!/bin/bash
set -eu
test -f "$(dirname "$0")/../.git/HEAD"
printf '%s\\n' "$*" >> "$ARTLOG_TEST_COMMAND_LOG"
`, {mode: 0o755});
    fs.writeFileSync(path.join(bin, 'git'), `#!/bin/bash
set -eu
if [ "$1" = -C ]; then
  test -f "$2/.git/HEAD"
  exit
fi
test "$1" = clone
target="\${@: -1}"
mkdir -p "$target/bin" "$target/.git"
touch "$target/.git/HEAD"
cp "$ARTLOG_TEST_FLUTTER" "$target/bin/flutter"
printf 'clone\\n' >> "$ARTLOG_TEST_COMMAND_LOG"
`, {mode: 0o755});
    const install = () => execFileSync('/bin/bash', [fileURLToPath(new URL('./vercel-install.sh', import.meta.url))], {
      env: {...process.env, PATH: `${bin}:/usr/bin:/bin`, ARTLOG_FLUTTER_ROOT: sdk,
        ARTLOG_TEST_FLUTTER: launcher, ARTLOG_TEST_COMMAND_LOG: log},
      stdio: 'pipe',
    });
    install();
    fs.mkdirSync(path.join(sdk, 'bin/cache'), {recursive: true});
    fs.writeFileSync(path.join(sdk, 'bin/cache/downloaded-artifact'), 'cached');
    fs.rmSync(path.join(sdk, '.git'), {recursive: true});
    // Vercel can also put the restored launcher on PATH. It must not bypass
    // the missing-metadata check just because command -v finds an executable.
    fs.symlinkSync(path.join(sdk, 'bin/flutter'), path.join(bin, 'flutter'));
    install();
    assert.equal(fs.readFileSync(path.join(sdk, 'bin/cache/downloaded-artifact'), 'utf8'), 'cached');
    assert.equal(fs.existsSync(path.join(sdk, '.git')), true);
    fs.rmSync(path.join(sdk, '.git/HEAD'));
    install();
    assert.equal(fs.readFileSync(path.join(sdk, 'bin/cache/downloaded-artifact'), 'utf8'), 'cached');
    assert.equal(fs.existsSync(path.join(sdk, '.git/HEAD')), true);
    assert.deepEqual(fs.readFileSync(log, 'utf8').trim().split('\n'), [
      'clone', '--version', 'precache --web', 'pub get --enforce-lockfile',
      'clone', '--version', 'precache --web', 'pub get --enforce-lockfile',
      'clone', '--version', 'precache --web', 'pub get --enforce-lockfile',
    ]);
  } finally {
    fs.rmSync(temporary, {recursive: true, force: true});
  }
});
