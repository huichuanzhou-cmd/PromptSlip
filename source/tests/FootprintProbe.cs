using System;
using System.Diagnostics;
using System.IO;
using System.Windows.Forms;
using PromptSlip;

// Development-only probe. Never shipped in the portable executable bundle.
class FootprintProbe {
    [STAThread] static int Main() {
        var startup = Stopwatch.StartNew();
        Application.EnableVisualStyles();
        Application.SetCompatibleTextRenderingDefault(false);
        string root = Path.Combine(Path.GetTempPath(), "PromptSlip-footprint-" + Guid.NewGuid().ToString("N"));
        using (var form = new MainForm(root)) {
            form.ShowInTaskbar = false;
            form.Opacity = 0;
            long ready = 0;
            var timer = new Timer { Interval = 1500 };
            form.Shown += delegate { ready = startup.ElapsedMilliseconds; timer.Start(); };
            timer.Tick += delegate {
                timer.Stop();
                var process = Process.GetCurrentProcess(); process.Refresh();
                Console.WriteLine("{\"scope\":\"isolated empty WinForms GUI, native handles and message loop, invisible test window; includes probe and .NET\",\"readyMs\":" + ready + ",\"workingSetBytes\":" + process.WorkingSet64 + ",\"privateBytes\":" + process.PrivateMemorySize64 + "}");
                form.Close();
            };
            Application.Run(form);
            timer.Dispose();
        }
        return 0;
    }
}
