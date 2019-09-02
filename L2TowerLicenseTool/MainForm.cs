using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Text;
using System.IO;
using System.Threading.Tasks;
using System.Windows.Forms;
using System.Threading;
using System.Management;
using System.Security.Cryptography;
using System.Diagnostics;

namespace LicenseTool
{
    public partial class MainForm : Form
    {
        delegate void SetTextCallback(TextBox t, string text);

        delegate void SetComboCallback(ComboBox t, string id);

        delegate void SetWindowTitle(Form t, string text);

        FileSystemWatcher fw;

        MemoryEditor mem = new MemoryEditor(Process.GetCurrentProcess().Handle);

        ProcessModule l2towerutils;

        private void tryLoadLicenseFile()
        {
            string licFile = Path.Combine(Path.GetDirectoryName(Application.ExecutablePath), @"settings\license.cfg");
            if (File.Exists(licFile))
            {
                SetText(licenseFile, licFile);
            }
        }

        
        private void calc()
        {
            if (null == l2towerutils)
            {
                foreach (ProcessModule processModule in Process.GetCurrentProcess().Modules)
                {
                    if (processModule.FileName.Contains("L2TowerUtils"))
                    {
                        l2towerutils = processModule;
                        break;
                    }
                }
            };

            if ("" != licenseFile.Text && File.Exists(licenseFile.Text))
            {
                SetTitle(this, Properties.Resources.ResourceManager.GetString("ProgramName") + " - " + licenseFile.Text);

                try
                {
                    UInt32 lic = (UInt32)L2TowerUtils.Utils.CheckLicense(licenseFile.Text, towerId.Text);
                    SetText(licNumDec, lic.ToString());
                    SetText(licNumHex, String.Format("0x{0:X}", (int)lic));


                    SetText(licDate, L2TowerUtils.Utils.GetLicenseGenerateTime());
                    SetText(licUser, L2TowerUtils.Utils.GetLicenseUserName());
                    SetText(licVersion, L2TowerUtils.Utils.GetLicenseVersion());
                    SetText(licId, L2TowerUtils.Utils.GetLicenseKeyId());
                    SetText(licHw, L2TowerUtils.Utils.GetLicenseHardwareKey());

                    string licenseType = "Unknown (Invalid)";
                    switch (lic)
                    {
                        case 0X1BB23435: licenseType = "Premium (0x1BB23435)"; break;
                        case 0XA75EF3C1: licenseType = "Trial (0xA75EF3C1)"; break;
                        case 0X23423441: licenseType = "Free (0x23423441)"; break;
                    }
  
                    SetCombo(licType, licenseType);
                    //


                    

                    if (null != l2towerutils)
                    {
                        SetText(dllOffset, "0x" + l2towerutils.BaseAddress.ToString("x2").ToUpper());

                        SetText(licHash, mem.ReadStringFromPtr(IntPtr.Add(l2towerutils.BaseAddress, 0xC62B8), Encoding.ASCII));

                        SetText(srvKey, mem.ReadStringFromPtr(IntPtr.Add(l2towerutils.BaseAddress, 0xC6318), Encoding.ASCII));
                    }
                }
                catch (Exception e) {

                    ClearLicenseValues();
                    SetTitle(this, Properties.Resources.ResourceManager.GetString("ProgramName") + " - Exception: " + e.Message);
                }
 
            }
            else
            {
                ClearLicenseValues();
                SetTitle(this, Properties.Resources.ResourceManager.GetString("ProgramName"));
            }

        }

        private void ClearLicenseValues()
        {
            var enumTextBoxes = licPanel.Controls.OfType<TextBox>().GetEnumerator();
            while (enumTextBoxes.MoveNext()) SetText(enumTextBoxes.Current, "");

            var enumComboBoxes = licPanel.Controls.OfType<ComboBox>().GetEnumerator();
            while (enumComboBoxes.MoveNext()) SetCombo(enumComboBoxes.Current, "");
        }

        public MainForm()
        {
            InitializeComponent();
        }


        private void Form1_Load(object sender, EventArgs e)
        {
            init();
        }

        private void init()
        {
            SetText(cpuId, Program.GetProcessorId());
            SetText(hddId, Program.GetHarddriveId());
            string l2HwId = Program.HashString(Program.GetProcessorId() + Program.GetHarddriveId());
            SetText(towerId, l2HwId);

            tryLoadLicenseFile();
            calc();
        }

        private void SetText(TextBox t, string text)
        {
            if (t.InvokeRequired)
            {

                this.Invoke(new SetTextCallback(SetText), new object[] { t, text });
            }
            else
            {
                t.Text = text;
            }
        }

        private void SetCombo(ComboBox t, string value)
        {
            if (t.InvokeRequired)
            {

                this.Invoke(new SetComboCallback(SetCombo), new object[] { t, value });
            }
            else
            {
                t.SelectedIndex = t.Items.IndexOf(value);
            }
        }
        private void SetTitle(Form t, string text)
        {
            if (t.InvokeRequired)
            {

                this.Invoke(new SetWindowTitle(SetTitle), new object[] { t, text });
            }
            else
            {
                t.Text = text;
            }
        }

        private void browseBtn_Click(object sender, EventArgs e)
        {
            OpenFileDialog fdlg = new OpenFileDialog();
            fdlg.Title = "L2Tower License File";
            //fdlg.InitialDirectory = @"c:\";
            fdlg.Filter = "L2Tower License|license.cfg|All files (*.*)|*.*";
            fdlg.FilterIndex = 1;
            fdlg.RestoreDirectory = true;
            if (fdlg.ShowDialog() == DialogResult.OK)
            {
                licenseFile.Text = fdlg.FileName;
            }
        }

        private void refreshBtn_Click(object sender, EventArgs e)
        {
            calc();
        }

        private void licenseFile_TextChanged(object sender, EventArgs e)
        {
            if (File.Exists(licenseFile.Text))
            {
                calc();
                if (null != fw)
                {
                    fw.Dispose();
                }

                fw = new FileSystemWatcher();
                fw.Path = Path.GetDirectoryName(licenseFile.Text);
                fw.Filter = Path.GetFileName(licenseFile.Text);
                fw.NotifyFilter = NotifyFilters.LastAccess | NotifyFilters.LastWrite | NotifyFilters.FileName;
                fw.Changed += new FileSystemEventHandler(OnLicenseChanged);
                fw.EnableRaisingEvents = true;
            }

        }

        private void OnLicenseChanged(object source, FileSystemEventArgs e)
        {
            calc();
        }

        private void resetBtn_Click(object sender, EventArgs e)
        {
            init();
        }

        private void towerId_TextChanged(object sender, EventArgs e)
        {
            calc();
        }

        private void hddId_TextChanged(object sender, EventArgs e)
        {
            string l2HwId = Program.HashString(cpuId.Text + hddId.Text);
            SetText(towerId, l2HwId);
            calc();
        }

        private void cpuId_TextChanged(object sender, EventArgs e)
        {
            string l2HwId = Program.HashString(cpuId.Text + hddId.Text);
            SetText(towerId, l2HwId);
            calc();
        }

        private void licDateBtn_Click(object sender, EventArgs e)
        {
            SetText(licDate, L2TowerUtils.Utils.GetLicenseGenerateTime());
        }

        private void licUserBtn_Click(object sender, EventArgs e)
        {
            SetText(licUser, L2TowerUtils.Utils.GetLicenseUserName());
        }

        private void licVersionBtn_Click(object sender, EventArgs e)
        {
            SetText(licVersion, L2TowerUtils.Utils.GetLicenseVersion());
        }

        private void licIdBtn_Click(object sender, EventArgs e)
        {
            SetText(licId, L2TowerUtils.Utils.GetLicenseKeyId());
        }

        private void licHwBtn_Click(object sender, EventArgs e)
        {
            SetText(licHw, L2TowerUtils.Utils.GetLicenseHardwareKey());
        }

        private void srvKeyBtn_Click(object sender, EventArgs e)
        {
            if (null != l2towerutils)
            {
                SetText(srvKey, mem.ReadStringFromPtr(IntPtr.Add(l2towerutils.BaseAddress, 0xC6318), Encoding.ASCII));
            }    
        }

        private void licHashBtn_Click(object sender, EventArgs e)
        {
            if (null != l2towerutils)
            {
                SetText(licHash, mem.ReadStringFromPtr(IntPtr.Add(l2towerutils.BaseAddress, 0xC62B8), Encoding.ASCII));
            }  
        }


    }
}
