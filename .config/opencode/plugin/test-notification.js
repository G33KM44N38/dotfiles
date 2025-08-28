import { NotificationPlugin } from './dist/notification.js';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

// Mock the required inputs
const mockClient = {};
const mockApp = {};
const mockShell = (strings, ...expressions) => {
  const command = strings.reduce((acc, str, i) => acc + str + (expressions[i] || ''), '');
  console.log('Executing command:', command);
  
  // Actually execute the command
  const promise = execAsync(command).then(({ stdout, stderr }) => ({
    stdout: Buffer.from(stdout),
    stderr: Buffer.from(stderr),
    exitCode: 0,
    text: () => stdout
  })).catch(error => ({
    stdout: Buffer.from(''),
    stderr: Buffer.from(error.message),
    exitCode: error.code || 1,
    text: () => ''
  }));
  
  // Add the methods that BunShellPromise has
  promise.stdin = null;
  promise.cwd = () => promise;
  promise.env = () => promise;
  promise.quiet = () => promise;
  promise.lines = () => [];
  promise.text = () => promise.then(result => result.text());
  promise.json = () => promise.then(() => ({}));
  promise.arrayBuffer = () => promise.then(() => new ArrayBuffer(0));
  promise.blob = () => promise.then(() => new Blob());
  promise.nothrow = () => promise;
  promise.throws = () => promise;
  
  return promise;
};

async function testPlugin() {
  console.log('Testing NotificationPlugin...');
  
  const plugin = await NotificationPlugin({ 
    client: mockClient, 
    app: mockApp, 
    $: mockShell 
  });
  
  console.log('Plugin initialized, calling event handler...');
  
  // Simulate an event
  await plugin.event({ event: { type: 'session.idle' } });
  
  console.log('Test completed!');
}

testPlugin().catch(console.error);
