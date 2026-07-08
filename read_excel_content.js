const ExcelJS = require('exceljs');
const path = require('path');

async function main() {
  const wb = new ExcelJS.Workbook();
  await wb.xlsx.readFile(path.join(__dirname, 'HAM_Data_Dictionary_v12.xlsx'));

  wb.eachSheet(ws => {
    console.log('\n========== SHEET: ' + ws.name + ' ==========');
    ws.eachRow((row, rowNum) => {
      const vals = [];
      row.eachCell({includeEmpty: false}, (cell) => {
        if (cell.value && String(cell.value).trim()) vals.push('[C' + cell.col + ']' + String(cell.value).substring(0, 80));
      });
      if (vals.length) console.log('R' + rowNum + ': ' + vals.join(' | '));
    });
  });
}
main().catch(e => { console.error(e); process.exit(1); });
