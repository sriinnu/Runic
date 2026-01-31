/**
 * @file storage.ts
 * @description Async storage wrapper with type safety and error handling.
 * Provides a simple key-value storage interface using AsyncStorage.
 */

import AsyncStorage from '@react-native-async-storage/async-storage';

/**
 * Storage keys used throughout the application.
 * Centralized to prevent typos and ensure consistency.
 */
export const STORAGE_KEYS = {
  PROVIDERS: '@runic/providers',
  SETTINGS: '@runic/settings',
  APP_STATE: '@runic/app_state',
  CACHE_PREFIX: '@runic/cache/',
  AUTH_TOKENS: '@runic/auth_tokens',
} as const;

/**
 * Stores a value in AsyncStorage with JSON serialization.
 *
 * @param key - Storage key
 * @param value - Value to store (will be JSON stringified)
 * @returns Promise that resolves when storage is complete
 *
 * @example
 * await storeData(STORAGE_KEYS.SETTINGS, { theme: 'dark' });
 */
export async function storeData<T>(key: string, value: T): Promise<void> {
  try {
    const jsonValue = JSON.stringify(value);
    await AsyncStorage.setItem(key, jsonValue);
  } catch (error) {
    console.error(`Error storing data for key "${key}":`, error);
    throw new Error(`Failed to store data: ${error}`);
  }
}

/**
 * Retrieves and deserializes a value from AsyncStorage.
 *
 * @param key - Storage key
 * @returns Promise that resolves with the stored value or null if not found
 *
 * @example
 * const settings = await getData<AppSettings>(STORAGE_KEYS.SETTINGS);
 */
export async function getData<T>(key: string): Promise<T | null> {
  try {
    const jsonValue = await AsyncStorage.getItem(key);
    return jsonValue != null ? JSON.parse(jsonValue) : null;
  } catch (error) {
    console.error(`Error retrieving data for key "${key}":`, error);
    return null;
  }
}

/**
 * Removes a value from AsyncStorage.
 *
 * @param key - Storage key
 * @returns Promise that resolves when removal is complete
 *
 * @example
 * await removeData(STORAGE_KEYS.CACHE_PREFIX + 'old_data');
 */
export async function removeData(key: string): Promise<void> {
  try {
    await AsyncStorage.removeItem(key);
  } catch (error) {
    console.error(`Error removing data for key "${key}":`, error);
    throw new Error(`Failed to remove data: ${error}`);
  }
}

/**
 * Clears all data from AsyncStorage.
 * Use with caution - this removes ALL stored data.
 *
 * @returns Promise that resolves when clear is complete
 *
 * @example
 * await clearAllData(); // Clears everything
 */
export async function clearAllData(): Promise<void> {
  try {
    await AsyncStorage.clear();
  } catch (error) {
    console.error('Error clearing all data:', error);
    throw new Error(`Failed to clear data: ${error}`);
  }
}

/**
 * Gets all keys currently stored in AsyncStorage.
 *
 * @returns Promise that resolves with array of all keys
 *
 * @example
 * const keys = await getAllKeys();
 */
export async function getAllKeys(): Promise<readonly string[]> {
  try {
    return await AsyncStorage.getAllKeys();
  } catch (error) {
    console.error('Error getting all keys:', error);
    return [];
  }
}

/**
 * Stores data with an expiration time for caching purposes.
 *
 * @param key - Storage key
 * @param value - Value to cache
 * @param ttlMinutes - Time to live in minutes
 * @returns Promise that resolves when cache is stored
 *
 * @example
 * await cacheData('user_data', userData, 60); // Cache for 1 hour
 */
export async function cacheData<T>(
  key: string,
  value: T,
  ttlMinutes: number
): Promise<void> {
  const cacheKey = STORAGE_KEYS.CACHE_PREFIX + key;
  const expiresAt = Date.now() + ttlMinutes * 60 * 1000;

  const cacheEntry = {
    value,
    expiresAt,
  };

  await storeData(cacheKey, cacheEntry);
}

/**
 * Retrieves cached data if it hasn't expired.
 *
 * @param key - Storage key (without cache prefix)
 * @returns Promise that resolves with cached value or null if expired/not found
 *
 * @example
 * const cachedData = await getCachedData<UserData>('user_data');
 */
export async function getCachedData<T>(key: string): Promise<T | null> {
  const cacheKey = STORAGE_KEYS.CACHE_PREFIX + key;
  const cacheEntry = await getData<{ value: T; expiresAt: number }>(cacheKey);

  if (!cacheEntry) {
    return null;
  }

  // Check if cache has expired
  if (Date.now() > cacheEntry.expiresAt) {
    await removeData(cacheKey);
    return null;
  }

  return cacheEntry.value;
}

/**
 * Clears all expired cache entries.
 *
 * @returns Promise that resolves when cleanup is complete
 *
 * @example
 * await clearExpiredCache(); // Run periodically to clean up
 */
export async function clearExpiredCache(): Promise<void> {
  try {
    const allKeys = await getAllKeys();
    const cacheKeys = allKeys.filter((key) =>
      key.startsWith(STORAGE_KEYS.CACHE_PREFIX)
    );

    const now = Date.now();

    for (const key of cacheKeys) {
      const entry = await getData<{ expiresAt: number }>(key);
      if (entry && now > entry.expiresAt) {
        await removeData(key);
      }
    }
  } catch (error) {
    console.error('Error clearing expired cache:', error);
  }
}
