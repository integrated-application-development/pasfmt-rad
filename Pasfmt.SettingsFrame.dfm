object PasfmtSettingsFrame: TPasfmtSettingsFrame
  Left = 0
  Top = 0
  Width = 390
  Height = 334
  Constraints.MinHeight = 180
  Constraints.MinWidth = 390
  TabOrder = 0
  object LogLevelLabel: TLabel
    Left = 3
    Top = 48
    Width = 126
    Height = 15
    Caption = 'Minimum log severity'
  end
  object ExePathLabel: TLabel
    Left = 3
    Top = 159
    Width = 103
    Height = 15
    Caption = 'Executable location'
  end
  object UserSettingsLabel: TLabel
    Left = 3
    Top = 3
    Width = 67
    Height = 15
    Caption = 'User settings'
  end
  object TimeoutLabel: TLabel
    Left = 3
    Top = 104
    Width = 110
    Height = 15
    Caption = 'Format timeout (ms)'
  end
  object LogLevelCombo: TComboBox
    Left = 11
    Top = 66
    Width = 129
    Height = 23
    Style = csDropDownList
    TabOrder = 0
    Items.Strings = (
      'Debug'
      'Info'
      'Warn'
      'Error'
      'None')
  end
  object ExePathBrowseButton: TButton
    Left = 309
    Top = 246
    Width = 71
    Height = 23
    Caption = 'Browse...'
    TabOrder = 2
    OnClick = ExePathBrowseButtonClick
  end
  object ExePathRadioGroup: TRadioGroup
    Left = 3
    Top = 159
    Width = 185
    Height = 65
    ItemIndex = 0
    Items.Strings = (
      'Detect automatically'
      'At specific path')
    ShowFrame = False
    TabOrder = 3
    OnClick = ExePathRadioGroupClick
  end
  object ExePathEdit: TEdit
    Left = 29
    Top = 223
    Width = 351
    Height = 23
    TabOrder = 1
  end
  object OnSaveCheckBox: TCheckBox
    Left = 11
    Top = 21
    Width = 105
    Height = 17
    Caption = 'Format on save'
    TabOrder = 4
  end
  object TimeoutEdit: TEdit
    Left = 11
    Top = 122
    Width = 129
    Height = 23
    NumbersOnly = True
    ParentShowHint = False
    ShowHint = True
    TabOrder = 5
    Text = '500'
  end
  object ExeChooseDialog: TOpenDialog
    Filter = 'Executable files (*.exe)|*.exe'
    Options = [ofHideReadOnly, ofPathMustExist, ofFileMustExist, ofEnableSizing]
    Left = 291
    Top = 52
  end
end
