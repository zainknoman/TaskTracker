let _switchView = null;
export function setRouter(fn) { _switchView = fn; }
export function navigate(view) { _switchView?.(view); }
