// Shared headless service: viewport detection + per-component user preferences.
// Consumers: import { subscribe, getPreference, setPreference } from 'c/hamViewportService';
//
// MVP storage: browser localStorage under the key 'hamDisplayPrefs'.
// To upgrade to Custom Setting / User fields later, swap the bodies of
// getPreference / setPreference — consumers do not change.

const BREAKPOINT_PX = 768;
const STORAGE_KEY = 'hamDisplayPrefs';
const subscribers = new Set();
let debounceTimer;

function getViewport() {
    const width = window.innerWidth;
    return {
        width,
        isMobile: width <= BREAKPOINT_PX,
        breakpoint: BREAKPOINT_PX
    };
}

function notify() {
    const v = getViewport();
    subscribers.forEach(cb => cb(v));
}

// Single shared resize listener, debounced ~100ms
// eslint-disable-next-line @lwc/lwc/no-async-operation
window.addEventListener('resize', () => {
    clearTimeout(debounceTimer);
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    debounceTimer = setTimeout(notify, 100);
});

export function subscribe(callback) {
    subscribers.add(callback);
    callback(getViewport()); // fire once immediately so caller has initial state
    return () => subscribers.delete(callback);
}

export function getPreference(componentKey) {
    try {
        const all = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
        return all[componentKey] || 'show';
    } catch (e) {
        return 'show';
    }
}

export function setPreference(componentKey, value) {
    try {
        const all = JSON.parse(localStorage.getItem(STORAGE_KEY) || '{}');
        all[componentKey] = value;
        localStorage.setItem(STORAGE_KEY, JSON.stringify(all));
        notify();
    } catch (e) {
        // localStorage unavailable (private mode, sandboxing) — silently skip
    }
}