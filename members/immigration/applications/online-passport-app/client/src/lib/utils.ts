import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Currency shown on fees and payments: FLC, the Farajaland Currency, a made-up
// code. A real deployment sets its ISO 4217 code here.
export const CURRENCY = "FLC"
