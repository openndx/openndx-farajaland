import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

// Currency shown on fees and payments. Farajaland is fictional, and so is this
// code; set the deployment's ISO 4217 code here.
export const CURRENCY = "FLD"
