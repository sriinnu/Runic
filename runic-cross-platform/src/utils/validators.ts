/**
 * @file validators.ts
 * @description Input validation utilities for API tokens, URLs, and user input.
 * Ensures data integrity and prevents security issues.
 */

import type { ProviderId } from '../types';

/**
 * Validates an API token format.
 * Checks for minimum length and allowed characters.
 *
 * @param token - The API token to validate
 * @returns True if token is valid, false otherwise
 *
 * @example
 * isValidApiToken('sk-1234567890abcdef') // true
 * isValidApiToken('123') // false (too short)
 */
export function isValidApiToken(token: string): boolean {
  if (!token || token.trim().length === 0) {
    return false;
  }

  // Minimum length of 20 characters for security
  if (token.length < 20) {
    return false;
  }

  // Allow alphanumeric, hyphens, and underscores
  const validPattern = /^[a-zA-Z0-9_-]+$/;
  return validPattern.test(token);
}

/**
 * Validates a URL format.
 *
 * @param url - The URL string to validate
 * @returns True if URL is valid, false otherwise
 *
 * @example
 * isValidUrl('https://api.example.com') // true
 * isValidUrl('not-a-url') // false
 */
export function isValidUrl(url: string): boolean {
  try {
    const urlObj = new URL(url);
    return urlObj.protocol === 'http:' || urlObj.protocol === 'https:';
  } catch {
    return false;
  }
}

/**
 * Validates an email address format.
 *
 * @param email - The email address to validate
 * @returns True if email is valid, false otherwise
 *
 * @example
 * isValidEmail('user@example.com') // true
 * isValidEmail('invalid-email') // false
 */
export function isValidEmail(email: string): boolean {
  const emailPattern = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailPattern.test(email);
}

/**
 * Validates a provider ID against known providers.
 *
 * @param id - The provider ID to validate
 * @returns True if provider ID is valid, false otherwise
 *
 * @example
 * isValidProviderId('openai') // true
 * isValidProviderId('unknown') // false
 */
export function isValidProviderId(id: string): id is ProviderId {
  const validProviders: ProviderId[] = [
    'openai',
    'anthropic',
    'google',
    'mistral',
    'cohere',
    'minimax',
    'groq',
    'openrouter',
  ];
  return validProviders.includes(id as ProviderId);
}

/**
 * Validates a percentage value (0-100).
 *
 * @param value - The percentage value to validate
 * @returns True if percentage is valid, false otherwise
 *
 * @example
 * isValidPercentage(75) // true
 * isValidPercentage(150) // false
 */
export function isValidPercentage(value: number): boolean {
  return value >= 0 && value <= 100;
}

/**
 * Validates a time in 24-hour format (0-23).
 *
 * @param hour - The hour value to validate
 * @returns True if hour is valid, false otherwise
 *
 * @example
 * isValidHour(15) // true
 * isValidHour(25) // false
 */
export function isValidHour(hour: number): boolean {
  return Number.isInteger(hour) && hour >= 0 && hour <= 23;
}

/**
 * Validates a refresh interval in minutes.
 * Must be at least 5 minutes to prevent excessive API calls.
 *
 * @param minutes - The interval in minutes
 * @returns True if interval is valid, false otherwise
 *
 * @example
 * isValidRefreshInterval(15) // true
 * isValidRefreshInterval(2) // false (too short)
 */
export function isValidRefreshInterval(minutes: number): boolean {
  return Number.isInteger(minutes) && minutes >= 5 && minutes <= 1440; // Max 24 hours
}

/**
 * Sanitizes a string by removing potentially harmful characters.
 *
 * @param input - The string to sanitize
 * @returns Sanitized string
 *
 * @example
 * sanitizeString('<script>alert("xss")</script>') // Returns sanitized version
 */
export function sanitizeString(input: string): string {
  return input
    .replace(/[<>]/g, '') // Remove angle brackets
    .replace(/javascript:/gi, '') // Remove javascript: protocol
    .replace(/on\w+=/gi, '') // Remove event handlers
    .trim();
}

/**
 * Validates that a number is positive.
 *
 * @param value - The number to validate
 * @returns True if number is positive, false otherwise
 *
 * @example
 * isPositiveNumber(10) // true
 * isPositiveNumber(-5) // false
 */
export function isPositiveNumber(value: number): boolean {
  return typeof value === 'number' && value > 0 && !isNaN(value);
}

/**
 * Validates that a string is not empty or just whitespace.
 *
 * @param value - The string to validate
 * @returns True if string is not empty, false otherwise
 *
 * @example
 * isNotEmpty('Hello') // true
 * isNotEmpty('   ') // false
 */
export function isNotEmpty(value: string): boolean {
  return value != null && value.trim().length > 0;
}
