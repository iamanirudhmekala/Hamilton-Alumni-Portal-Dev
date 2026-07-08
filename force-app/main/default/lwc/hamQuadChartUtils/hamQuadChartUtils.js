import { loadScript } from 'lightning/platformResourceLoader';
import CHARTJS from '@salesforce/resourceUrl/HAMQuadChartJS';

const HAMILTON = {
    navy: '#0A2E5C',
    navyDeep: '#061D3D',
    gold: '#C9A227',
    goldLight: '#E4C765',
    paper: '#F7F5EF',
    ink: '#1B2430',
    slate: '#5B6472',
    line: '#E1DCCB',
    good: '#2F7A4F',
    warn: '#B4552C'
};

export function loadChartJs(component) {
    return loadScript(component, CHARTJS);
}

export function createChart(canvas, config) {
    // eslint-disable-next-line no-undef
    return new Chart(canvas.getContext('2d'), config);
}

export function destroyChart(chartInstance) {
    if (chartInstance) {
        chartInstance.destroy();
    }
}

export function fmt(n) {
    if (n === null || n === undefined) {
        return '0';
    }
    return Number(n).toLocaleString('en-US');
}

export function pct(numerator, denominator) {
    if (!denominator) {
        return '0.0';
    }
    return ((numerator / denominator) * 100).toFixed(1);
}

export { HAMILTON };