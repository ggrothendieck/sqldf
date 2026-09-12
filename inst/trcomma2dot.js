// Convert commas in stdin to dot in stdout.
// To run: ... | cscript /Nolog trcomma2dot.js
while (!WScript.StdIn.AtEndOfStream) {
    var line = WScript.StdIn.ReadLine();
    WScript.StdOut.WriteLine(line.replace(/,/g, '.'));
}
