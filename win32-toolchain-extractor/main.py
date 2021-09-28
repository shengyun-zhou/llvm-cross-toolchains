import tar_extractor
import os
import winreg
from sys import exit
import traceback
import wx
import ctypes
import threading
import package_tar_info

DEFAULT_TARGET_DIR_NAME = 'llvm-cross-toolchains'

if __name__ == '__main__':
    try:
        # Enable hidpi support
        ctypes.windll.shcore.SetProcessDpiAwareness(2)
        ctypes.windll.user32.SetProcessDPIAware()
    except:
        traceback.print_exc()

    # Generated with wxFormBuilder (version Oct 26 2018)
    class ExtractorAppFrame ( wx.Frame ):
        def __init__( self, parent ):
            wx.Frame.__init__ ( self, parent, id = wx.ID_ANY, title = u"Toolchain Extractor", pos = wx.DefaultPosition, size = wx.Size( 800,480 ), style = wx.DEFAULT_FRAME_STYLE|wx.TAB_TRAVERSAL )

            self.SetSizeHints( wx.DefaultSize, wx.DefaultSize )
            self.SetBackgroundColour( wx.SystemSettings.GetColour( wx.SYS_COLOUR_WINDOW ) )

            _bsizer1 = wx.BoxSizer( wx.VERTICAL )

            self.m_info_output_text = wx.TextCtrl( self, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, wx.TE_AUTO_URL|wx.TE_BESTWRAP|wx.TE_MULTILINE|wx.TE_READONLY )
            _bsizer1.Add( self.m_info_output_text, 1, wx.ALL|wx.EXPAND, 5 )

            self.m_progress_bar = wx.Gauge( self, wx.ID_ANY, 100, wx.DefaultPosition, wx.Size( -1,-1 ), wx.GA_HORIZONTAL )
            self.m_progress_bar.SetValue( 0 )
            if package_tar_info.FILE_COUNT > 0:
                self.m_progress_bar.SetRange(package_tar_info.FILE_COUNT)
            _bsizer1.Add( self.m_progress_bar, 0, wx.ALL|wx.EXPAND, 5 )

            self.m_ctext1 = wx.StaticText( self, wx.ID_ANY, u"Directory path to extract toolchain: ", wx.DefaultPosition, wx.DefaultSize, 0 )
            self.m_ctext1.Wrap( -1 )

            _bsizer1.Add( self.m_ctext1, 0, wx.LEFT|wx.TOP, 5 )

            _bsizer2 = wx.BoxSizer( wx.HORIZONTAL )

            self.m_target_dir_text = wx.TextCtrl( self, wx.ID_ANY, wx.EmptyString, wx.DefaultPosition, wx.DefaultSize, 0 )
            self.m_target_dir_text.SetValue(os.path.join(os.getcwd(), DEFAULT_TARGET_DIR_NAME))
            _bsizer2.Add( self.m_target_dir_text, 1, wx.ALL|wx.ALIGN_CENTER_VERTICAL, 5 )

            self.m_target_dir_picker = wx.DirPickerCtrl( self, wx.ID_ANY, wx.EmptyString, u"Select a folder", wx.DefaultPosition, wx.DefaultSize, wx.DIRP_DIR_MUST_EXIST )
            self.m_target_dir_picker.Bind(wx.EVT_DIRPICKER_CHANGED, lambda e : self.m_target_dir_text.SetValue(os.path.join(e.GetPath(), DEFAULT_TARGET_DIR_NAME)))
            _bsizer2.Add( self.m_target_dir_picker, 0, wx.ALL|wx.ALIGN_CENTER_VERTICAL, 5 )

            self.m_ctrl_btn = wx.Button( self, wx.ID_ANY, u"Start", wx.DefaultPosition, wx.DefaultSize, 0 )
            self.m_ctrl_btn.Bind(wx.EVT_BUTTON, self.on_ctrl_btn_clicked)
            _bsizer2.Add( self.m_ctrl_btn, 0, wx.ALL|wx.ALIGN_CENTER_VERTICAL, 5 )

            _bsizer1.Add( _bsizer2, 0, wx.EXPAND, 5 )

            self.SetSizer( _bsizer1 )
            self.Layout()
            self.Centre( wx.BOTH )
            self.ended = False

        def on_ctrl_btn_clicked(self, e):
            if not self.m_ctrl_btn.IsEnabled():
                return
            if self.ended:
                self.Close()
                return
            target_dir_path = self.m_target_dir_text.GetValue()
            if len(target_dir_path) == 0:
                wx.MessageBox('Directory path cannot be empty', 'Message' ,wx.OK | wx.ICON_INFORMATION)
                return
            try:
                os.makedirs(target_dir_path, exist_ok=True)
            except:
                wx.MessageBox('Directory %s does not exists and cannot be created' % target_dir_path, "Error" , wx.OK | wx.ICON_ERROR)
                return
            self.EnableCloseButton(False)
            self.m_target_dir_picker.Disable()
            self.m_target_dir_text.Disable()
            self.m_ctrl_btn.Disable()
            t = threading.Thread(target=self.async_extract, args=(target_dir_path, ))
            t.start()

        def async_extract(self, target_dir):
            try:
                tar_extractor.extract_tar(os.path.join(os.path.dirname(__file__), package_tar_info.FILE_NAME), directory=target_dir, strip_component_count=1, 
                                          verbose_output_cb=lambda s : self.m_info_output_text.AppendText(s + '\n'),
                                          progress_cb=lambda c : self.m_progress_bar.SetValue(min(c, package_tar_info.FILE_COUNT)) if package_tar_info.FILE_COUNT > 0 else 0)
                self.m_info_output_text.AppendText('\nExtraction finished\n')
                self.m_progress_bar.SetValue(self.m_progress_bar.GetRange())
                self.m_ctrl_btn.SetLabel('Finish')
            except:
                self.m_info_output_text.AppendText(traceback.format_exc() + '\n')
                self.m_info_output_text.AppendText('Extraction failed!\n')
                self.m_ctrl_btn.SetLabel('Quit')
            self.ended = True
            self.EnableCloseButton(True)
            self.m_ctrl_btn.Enable()

        def __del__( self ):
            pass


    wxapp = wx.App(None)
    app_frame = ExtractorAppFrame(None)
    app_frame.Show()

    long_path_enabled = False
    try:
        # Check if long path support is enabled
        regkey = winreg.OpenKey(winreg.HKEY_LOCAL_MACHINE, r'SYSTEM\CurrentControlSet\Control\FileSystem', access=(winreg.KEY_QUERY_VALUE | winreg.KEY_SET_VALUE))
        keyval, valtype = winreg.QueryValueEx(regkey, 'LongPathsEnabled')
        if valtype == winreg.REG_DWORD:
            if keyval == 0:
                winreg.SetValueEx(regkey, 'LongPathsEnabled', 0, winreg.REG_DWORD, 1)
                long_path_enabled = True
            else:
                long_path_enabled = True
    except:
        app_frame.m_info_output_text.AppendText(traceback.format_exc() + '\n')
    finally:
        regkey = None
    if not long_path_enabled:
        app_frame.m_info_output_text.AppendText(
              'WARNING: failed to enable filesystem long path support, '
              'you can follow https://docs.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=cmd#enable-long-paths-in-windows-10-version-1607-and-later to enable it manually in Windows 10 1607 and later.\n')
    else:
        app_frame.m_info_output_text.AppendText('Filesystem long path support is enabled.\n')

    wxapp.MainLoop()
    exit(0)
