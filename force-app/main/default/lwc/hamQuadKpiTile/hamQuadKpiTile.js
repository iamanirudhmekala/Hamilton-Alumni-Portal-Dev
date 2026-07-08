import { LightningElement, api } from 'lwc';
import { fmt, HAMILTON } from 'c/hamQuadChartUtils';

const TONE_MAP = {
    navy: HAMILTON.navy,
    gold: HAMILTON.gold,
    slate: HAMILTON.slate,
    warn: HAMILTON.warn,
    good: HAMILTON.good
};

export default class HamQuadKpiTile extends LightningElement {
    @api label;
    @api value = 0;
    @api sub;
    @api tone = 'navy'; // navy | gold | slate | warn | good
    @api big = false;

    get formattedValue() {
        return fmt(this.value);
    }

    get valueClass() {
        return this.big ? 'kpi-value kpi-value-big' : 'kpi-value';
    }

    get valueStyle() {
        const color = TONE_MAP[this.tone] || HAMILTON.navy;
        return `color: ${color};`;
    }
}