import { writable } from 'svelte/store';

export const modalTimer = writable(false);
export const modalServer = writable(false);
export const modalHold = writable(false);

export function focusSelect(selector) {
	setTimeout(() => {
		if (typeof document !== 'undefined') {
			const element = document.querySelector(selector);
			if (element) {
				element.focus();
				element.select();
			}
		}
	}, 0);
}

export function enterSubmit(launchFunction) {
	return (event) => {
		if (event.key === 'Enter') {
			launchFunction();
		}
	};
}