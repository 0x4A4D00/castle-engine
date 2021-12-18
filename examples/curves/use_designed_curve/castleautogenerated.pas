{ Auto-generated unit with information about the project.
  The information set here reflects the CastleEngineManifest.xml properties.

  You should not modify this file manually.
  Regenerate it using CGE editor "Code -> Regenerate Project" menu item
  (or command-line: "castle-engine generate-program"). }
unit CastleAutoGenerated;

interface

implementation

uses CastleApplicationProperties, CastleWindow, CastleLog;

initialization
  ApplicationProperties.ApplicationName := 'use_designed_curve';
  ApplicationProperties.Caption := 'Use Designed Curve';
  ApplicationProperties.Version := '0.1';

  if not IsLibrary then
    Application.ParseStandardParameters;

  { Start logging.

    Should be done after setting ApplicationProperties.ApplicationName/Version,
    since they are recorded in the first automatic log messages.

    Should be done after basic command-line parameters are parsed
    for standalone programs (when "not IsLibrary").
    This allows to handle --version and --help command-line parameters
    without any extra output on Unix, and to set --log-file . }
  InitializeLog;
end.