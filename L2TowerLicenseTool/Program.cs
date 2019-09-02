using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.Reflection;
using System.Text;
using System.IO;
using System.Diagnostics;
using System.Threading;
using System.Security.Permissions;
using System.Management;
using System.Security.Cryptography;

namespace LicenseTool
{


    static class Program
    {


        /// <summary>
        /// The main entry point for the application.
        /// </summary>
        [STAThread]
        [SecurityPermission(SecurityAction.Demand, Flags = SecurityPermissionFlag.ControlAppDomain)]
        static void Main()
        {
            AppDomain currentDomain = AppDomain.CurrentDomain;
            currentDomain.AssemblyResolve += new ResolveEventHandler(Program.currentDomain_AssemblyResolve);
            currentDomain.UnhandledException += new UnhandledExceptionEventHandler(Program.UnhandledExceptionHandler);
            Application.ThreadException += new ThreadExceptionEventHandler(Program.Application_ThreadException);

            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }

        private static Assembly currentDomain_AssemblyResolve(object sender, ResolveEventArgs args)
        {
            string assemblyFile = "";
            foreach (AssemblyName referencedAssembly in Assembly.GetExecutingAssembly().GetReferencedAssemblies())
            {
                if (referencedAssembly.FullName.Substring(0, referencedAssembly.FullName.IndexOf(",")) == args.Name.Substring(0, args.Name.IndexOf(",")))
                {
                    assemblyFile = Path.GetDirectoryName(Application.ExecutablePath) + "\\libs\\" + args.Name.Substring(0, args.Name.IndexOf(",")) + ".dll";
                    break;
                }
            }
            return Assembly.LoadFrom(assemblyFile);
        }

        private static void UnhandledExceptionHandler(object sender, UnhandledExceptionEventArgs args)
        {
            Exception exceptionObject = (Exception)args.ExceptionObject;
            int num = (int)MessageBox.Show("Error: " + ((Exception)args.ExceptionObject).Message, "L2Tower License Tool", MessageBoxButtons.OK, MessageBoxIcon.Hand);
        }

        private static void Application_ThreadException(object sender, ThreadExceptionEventArgs e)
        {
            int num = (int)MessageBox.Show("Error in thread: " + e.Exception.Message, "L2Tower License Tool", MessageBoxButtons.OK, MessageBoxIcon.Hand);
        }


        public static string GetProcessorId()
        {

            using (ManagementObjectSearcher managementObjectSearcher = new ManagementObjectSearcher("select ProcessorId from Win32_Processor"))
            {
                using (ManagementObjectCollection.ManagementObjectEnumerator enumerator = managementObjectSearcher.Get().GetEnumerator())
                {
                    if (enumerator.MoveNext())
                    {
                        ManagementObject managementObject = (ManagementObject)enumerator.Current;
                        return managementObject.GetPropertyValue("ProcessorId") as string;
                    }
                }
            }
            return "undefined";
        }

        public static string GetHarddriveId()
        {
            using (ManagementObjectSearcher managementObjectSearcher = new ManagementObjectSearcher("select PNPDeviceID from Win32_DiskDrive"))
            {
                foreach (string current in
                    from ManagementObject x in managementObjectSearcher.Get()
                    select x.GetPropertyValue("PNPDeviceID") as string)
                {
                    if (current != null && current.StartsWith("IDE\\"))
                    {
                        string result = current;
                        return result;
                    }
                    if (current != null && current.StartsWith("SCSI\\"))
                    {
                        string result = current;
                        return result;
                    }
                }
            }
            return "undefined";
        }

        public static string HashString(string value)
        {
            MD5CryptoServiceProvider mD5CryptoServiceProvider = new MD5CryptoServiceProvider();
            byte[] array = Encoding.ASCII.GetBytes(value);
            array = mD5CryptoServiceProvider.ComputeHash(array);
            return array.Aggregate(string.Empty, (string current, byte t) => current + t.ToString("x2").ToLower());
        }
    }
}
