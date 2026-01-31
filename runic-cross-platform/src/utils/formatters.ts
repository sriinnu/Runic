/**
 * @file formatters.ts
 * @description Utility functions for formatting numbers, currencies, dates, and other data.
 * Provides consistent formatting across the application.
 */

import { format, formatDistance, formatRelative } from 'date-fns';
import type { CurrencyCode } from '../types';

/**
 * Formats a number as currency with proper symbol and decimal places.
 *
 * @param amount - The numeric amount to format
 * @param currency - ISO 4217 currency code (e.g., 'USD', 'EUR')
 * @param showCents - Whether to show cents/decimal places
 * @returns Formatted currency string (e.g., "$10.50")
 *
 * @example
 * formatCurrency(10.5, 'USD', true) // "$10.50"
 * formatCurrency(10, 'USD', false) // "$10"
 */
export function formatCurrency(
  amount: number,
  currency: CurrencyCode = 'USD',
  showCents = true
): string {
  const formatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency,
    minimumFractionDigits: showCents ? 2 : 0,
    maximumFractionDigits: showCents ? 2 : 0,
  });

  return formatter.format(amount);
}

/**
 * Formats a large number with K/M/B suffixes for readability.
 *
 * @param num - The number to format
 * @param decimals - Number of decimal places to show
 * @returns Formatted string with suffix (e.g., "1.2K", "3.5M")
 *
 * @example
 * formatLargeNumber(1234) // "1.2K"
 * formatLargeNumber(1234567) // "1.2M"
 * formatLargeNumber(1234567890) // "1.2B"
 */
export function formatLargeNumber(num: number, decimals = 1): string {
  if (num < 1000) {
    return num.toString();
  }

  const units = ['K', 'M', 'B', 'T'];
  const order = Math.floor(Math.log10(num) / 3);
  const unitName = units[order - 1];
  const numInUnit = num / Math.pow(1000, order);

  return `${numInUnit.toFixed(decimals)}${unitName}`;
}

/**
 * Formats a number with thousands separators.
 *
 * @param num - The number to format
 * @returns Formatted string with commas (e.g., "1,234,567")
 *
 * @example
 * formatNumber(1234567) // "1,234,567"
 */
export function formatNumber(num: number): string {
  return new Intl.NumberFormat('en-US').format(num);
}

/**
 * Formats a percentage value.
 *
 * @param value - The percentage value (0-100)
 * @param decimals - Number of decimal places
 * @returns Formatted percentage string (e.g., "75.5%")
 *
 * @example
 * formatPercentage(75.5) // "75.5%"
 * formatPercentage(75.555, 1) // "75.6%"
 */
export function formatPercentage(value: number, decimals = 1): string {
  return `${value.toFixed(decimals)}%`;
}

/**
 * Formats a timestamp as a human-readable date string.
 *
 * @param timestamp - Unix timestamp in milliseconds
 * @param formatStr - Date format string (date-fns format)
 * @returns Formatted date string
 *
 * @example
 * formatDate(Date.now()) // "Jan 31, 2026"
 * formatDate(Date.now(), 'PPpp') // "Jan 31, 2026, 3:45:00 PM"
 */
export function formatDate(timestamp: number, formatStr = 'PPP'): string {
  return format(timestamp, formatStr);
}

/**
 * Formats a timestamp as relative time (e.g., "2 hours ago").
 *
 * @param timestamp - Unix timestamp in milliseconds
 * @returns Relative time string
 *
 * @example
 * formatRelativeTime(Date.now() - 3600000) // "about 1 hour ago"
 */
export function formatRelativeTime(timestamp: number): string {
  return formatDistance(timestamp, Date.now(), { addSuffix: true });
}

/**
 * Formats a timestamp as relative date with context.
 *
 * @param timestamp - Unix timestamp in milliseconds
 * @returns Relative date string with context
 *
 * @example
 * formatRelativeDate(Date.now()) // "today at 3:45 PM"
 */
export function formatRelativeDate(timestamp: number): string {
  return formatRelative(timestamp, Date.now());
}

/**
 * Truncates a string to a maximum length with ellipsis.
 *
 * @param str - The string to truncate
 * @param maxLength - Maximum length before truncation
 * @returns Truncated string with ellipsis if needed
 *
 * @example
 * truncateString("Hello World", 8) // "Hello..."
 */
export function truncateString(str: string, maxLength: number): string {
  if (str.length <= maxLength) {
    return str;
  }
  return `${str.slice(0, maxLength - 3)}...`;
}

/**
 * Formats bytes to human-readable size.
 *
 * @param bytes - Number of bytes
 * @param decimals - Number of decimal places
 * @returns Formatted size string (e.g., "1.5 MB")
 *
 * @example
 * formatBytes(1536000) // "1.5 MB"
 */
export function formatBytes(bytes: number, decimals = 2): string {
  if (bytes === 0) return '0 Bytes';

  const k = 1024;
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));

  return `${parseFloat((bytes / Math.pow(k, i)).toFixed(decimals))} ${sizes[i]}`;
}
