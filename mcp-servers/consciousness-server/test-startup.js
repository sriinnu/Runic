#!/usr/bin/env node

/**
 * Startup test for Runic Consciousness Server
 *
 * This script tests that the server can be imported and initialized
 * without throwing any errors.
 */

import { spawn } from 'child_process';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

console.log('Testing Runic Consciousness Server startup...\n');

// Build the project first
console.log('Building TypeScript...');
const buildProcess = spawn('npm', ['run', 'build'], {
  cwd: __dirname,
  stdio: 'inherit',
  shell: true
});

buildProcess.on('close', (buildCode) => {
  if (buildCode !== 0) {
    console.error(`\n❌ Build failed with code ${buildCode}`);
    process.exit(1);
  }

  console.log('\n✓ Build successful\n');
  console.log('Starting server (will timeout after 3 seconds if successful)...');

  // Start the server process
  const serverProcess = spawn('node', ['dist/index.js'], {
    cwd: __dirname,
    stdio: ['pipe', 'pipe', 'pipe'],
  });

  let output = '';
  let errorOutput = '';

  serverProcess.stdout.on('data', (data) => {
    output += data.toString();
    console.log('STDOUT:', data.toString());
  });

  serverProcess.stderr.on('data', (data) => {
    errorOutput += data.toString();
    console.log('STDERR:', data.toString());
  });

  // Give the server 3 seconds to start
  const timeout = setTimeout(() => {
    serverProcess.kill();

    // If no errors were thrown, consider it successful
    if (!errorOutput.includes('Error') && !errorOutput.includes('error')) {
      console.log('\n✓ Server started successfully (no errors detected)');
      console.log('✓ All startup tests passed!\n');
      process.exit(0);
    } else {
      console.error('\n❌ Server encountered errors:');
      console.error(errorOutput);
      process.exit(1);
    }
  }, 3000);

  serverProcess.on('error', (error) => {
    clearTimeout(timeout);
    console.error('\n❌ Failed to start server:', error.message);
    process.exit(1);
  });

  serverProcess.on('close', (code) => {
    clearTimeout(timeout);
    if (code !== 0 && code !== null) {
      console.error(`\n❌ Server exited with code ${code}`);
      if (errorOutput) {
        console.error('Error output:', errorOutput);
      }
      process.exit(1);
    }
  });
});
