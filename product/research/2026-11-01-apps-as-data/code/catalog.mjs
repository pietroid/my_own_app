// Which A2UI v0.9 basic-catalog components app_ui already draws.
// The basic list is the "components" keys of
// https://a2ui.org/specification/v0_9/catalogs/basic/catalog.json (read 2026-11-01).
// app_ui's widgets are the classes extending StatelessWidget/StatefulWidget
// under app/packages/app_ui/lib/src/widgets and app_icons.
// Run: node catalog.mjs > ../data/catalog.csv

import { readdirSync, readFileSync } from 'node:fs';

const BASIC = ['Text', 'Image', 'Icon', 'Video', 'AudioPlayer', 'Row', 'Column', 'List', 'Card', 'Tabs', 'Modal', 'Divider', 'Button', 'TextField', 'CheckBox', 'ChoicePicker', 'Slider', 'DateTimeInput'];
const root = new URL('../../../../app/packages/app_ui/lib/src/', import.meta.url);
const widgets = [];
for (const dir of ['widgets', 'app_icons']) {
  for (const f of readdirSync(new URL(dir + '/', root))) {
    const src = readFileSync(new URL(`${dir}/${f}`, root), 'utf8');
    for (const m of src.matchAll(/class (\w+) extends State(?:less|ful)Widget/g)) widgets.push(m[1]);
  }
}
// The app_ui widget that plays each A2UI part, by reading the code.
const twin = { Button: 'AppButton', Icon: 'AppIcon' };
console.log('a2ui_component,app_ui_widget');
for (const c of BASIC) console.log(`${c},${twin[c] && widgets.includes(twin[c]) ? twin[c] : ''}`);
console.error(`app_ui widgets: ${widgets.join(', ')}; basic components with a twin: ${Object.keys(twin).length} of ${BASIC.length}`);
