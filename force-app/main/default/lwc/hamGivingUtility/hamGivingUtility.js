export const MINIMUM_TOTAL_AMT = 5;
export const MAXIMUM_TOTAL_AMT = 999999;
export const MIN_PLEDGE_AMOUNT = 1;
export const MIN_DESIGNATION_AMOUNT = 1;

export function validateTotalAmount(amt) {
    return amt >= MINIMUM_TOTAL_AMT && amt <= MAXIMUM_TOTAL_AMT;
}

export function updateBtnState(btn, prop, tabName, activeClass, inactiveClass) {
    if (btn.dataset[prop] === tabName || btn[prop] === tabName) {
        btn.classList.add(activeClass);
        btn.classList.remove(inactiveClass);
    } else {
        btn.classList.remove(activeClass);
        btn.classList.add(inactiveClass);
    }
}