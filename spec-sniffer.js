/**
 * spec-sniffer.js
 *
 * A lightweight, multi-environment Javascript module to detect system specifications.
 * It is designed to run in Browsers, Node.js, Deno, Bun, and Web Workers (including Cloudflare Workers),
 * gracefully handling the APIs available in each environment.
 *
 * This script was created to fulfill a request to replicate the functionality of a
 * shell-based spec sniffer in Javascript, focusing on CPU cores, memory, and storage volume.
 *
 * - CPU Cores: Detects logical processor count.
 * - Memory: Provides total system RAM where possible (Node.js, Deno) or a device
 *   memory hint (browsers). Also includes JS heap size information where available.
 * - Storage: Provides origin-based storage quota in browsers.
 *
 * The main function is getSystemSpecs(), which returns a promise resolving to a
 * consolidated object of all available specs.
 */

/**
 * @typedef {'Browser' | 'Node.js' | 'Deno' | 'Bun' | 'Web Worker' | 'Unknown'} JSEnvironment
 */

/**
 * Detects the current JavaScript runtime environment.
 * This is a best-effort detection and might not cover all edge cases.
 * @returns {JSEnvironment} The name of the detected environment.
 */
function detectEnvironment() {
  // Check for Bun first, as it also defines 'process' like Node.js
  if (typeof process !== 'undefined' && process.versions && process.versions.bun) {
    return 'Bun';
  }
  // Check for Node.js
  if (typeof process !== 'undefined' && process.versions && process.versions.node) {
    return 'Node.js';
  }
  // Check for Deno
  if (typeof Deno !== 'undefined' && typeof Deno.version !== 'undefined') {
    return 'Deno';
  }
  // Check for a generic Web Worker environment (includes Service Workers and CF Workers)
  // `self` is the global scope in workers, and `window` will be undefined.
  if (typeof self === 'object' && self.constructor && self.constructor.name === 'DedicatedWorkerGlobalScope') {
      return 'Web Worker';
  }
  // A more generic worker check for environments like Cloudflare
  if (typeof self !== 'undefined' && typeof window === 'undefined') {
      return 'Web Worker';
  }
  // Check for the main browser thread
  if (typeof window !== 'undefined' && typeof window.document !== 'undefined') {
    return 'Browser';
  }
  return 'Unknown';
}

/**
 * Gets the number of logical CPU cores.
 * @returns {number | null} The number of cores, or null if not available.
 */
function getCpuCores() {
  // For browsers, Deno, and workers that support it
  if (typeof navigator !== 'undefined' && navigator.hardwareConcurrency) {
    return navigator.hardwareConcurrency;
  }

  // For Node.js and Bun
  try {
    // Using eval to hide 'require' from bundlers in non-Node environments.
    const os = eval("require('os')");
    if (os && typeof os.cpus === 'function') {
      return os.cpus().length;
    }
  } catch (e) {
    // 'require' will fail in non-Node environments, which is expected.
  }

  return null;
}

/**
 * @typedef {object} MemoryInfo
 * @property {number | null} deviceMemoryGB - Total system RAM in gigabytes (approximate, browser-only).
 * @property {number | null} totalMemoryGB - Total system RAM in gigabytes (Node.js/Deno only).
 * @property {number | null} jsHeapSizeLimitBytes - The maximum size of the JS heap, in bytes (Chrome-only).
 * @property {number | null} totalJSHeapSizeBytes - The total allocated JS heap size, in bytes (Chrome-only).
 * @property {number | null} usedJSHeapSizeBytes - The currently active JS heap size, in bytes (Chrome-only).
 */

/**
 * Gets information about memory.
 * Note: Values can vary greatly in availability and accuracy across environments.
 * @returns {Promise<MemoryInfo>} A promise that resolves to an object with memory details.
 */
async function getMemoryInfo() {
  const memoryInfo = {
    deviceMemoryGB: null,
    totalMemoryGB: null,
    jsHeapSizeLimitBytes: null,
    totalJSHeapSizeBytes: null,
    usedJSHeapSizeBytes: null,
  };

  // Browser and some worker environments
  if (typeof navigator !== 'undefined' && navigator.deviceMemory) {
    memoryInfo.deviceMemoryGB = navigator.deviceMemory;
  }
  if (typeof performance !== 'undefined' && performance.memory) {
    memoryInfo.jsHeapSizeLimitBytes = performance.memory.jsHeapSizeLimit;
    memoryInfo.totalJSHeapSizeBytes = performance.memory.totalJSHeapSize;
    memoryInfo.usedJSHeapSizeBytes = performance.memory.usedJSHeapSize;
  }

  // Node.js and Bun
  try {
    const os = eval("require('os')");
    if (os && typeof os.totalmem === 'function') {
      // os.totalmem() returns bytes. Convert to GB and round.
      memoryInfo.totalMemoryGB = Math.round(os.totalmem() / (1024 * 1024 * 1024));
    }
  } catch (e) { /* ignore */ }

  // Deno
  if (typeof Deno !== 'undefined' && typeof Deno.systemMemoryInfo === 'function') {
      const denoMem = Deno.systemMemoryInfo();
      memoryInfo.totalMemoryGB = Math.round(denoMem.total / (1024 * 1024 * 1024));
  }

  return memoryInfo;
}

/**
 * @typedef {object} StorageInfo
 * @property {number | null} quotaBytes - The total available storage space for the origin, in bytes.
 * @property {number | null} usageBytes - The amount of storage currently used by the origin, in bytes.
 */

/**
 * Gets information about storage quota and usage for the current origin.
 * This is typically only available in secure browser environments.
 * @returns {Promise<StorageInfo>} A promise that resolves to an object with storage details.
 */
async function getStorageInfo() {
  if (typeof navigator !== 'undefined' && typeof navigator.storage !== 'undefined' && typeof navigator.storage.estimate === 'function') {
    try {
      const { quota, usage } = await navigator.storage.estimate();
      return { quotaBytes: quota, usageBytes: usage };
    } catch (error) {
      // This can fail in some contexts (e.g., private browsing)
      console.warn("Storage estimation failed:", error);
      return { quotaBytes: null, usageBytes: null };
    }
  }
  return { quotaBytes: null, usageBytes: null };
}

/**
 * @typedef {object} SystemSpecs
 * @property {JSEnvironment} environment - The detected Javascript runtime.
 * @property {number | null} cpuCores - The number of logical CPU cores.
 * @property {MemoryInfo} memory - An object containing memory information.
 * @property {StorageInfo} storage - An object containing storage information.
 */

/**
 * Gathers all available system specifications into a single object.
 * @returns {Promise<SystemSpecs>} A promise that resolves to an object containing all detected specs.
 */
async function getSystemSpecs() {
  // Run async spec collections in parallel for efficiency
  const [memory, storage] = await Promise.all([
    getMemoryInfo(),
    getStorageInfo(),
  ]);

  return {
    environment: detectEnvironment(),
    cpuCores: getCpuCores(),
    memory: memory,
    storage: storage,
  };
}

// Export the main function for use in different environments (e.g., Node.js)
if (typeof module !== 'undefined' && typeof module.exports !== 'undefined') {
  module.exports = {
    getSystemSpecs,
    detectEnvironment,
    getCpuCores,
    getMemoryInfo,
    getStorageInfo
  };
}
