// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'fleather_localizations.g.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class FleatherLocalizationsPt extends FleatherLocalizations {
  FleatherLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get foregroundColorAutomatic => 'Automático';

  @override
  String get backgroundColorNoColor => 'Sem cor';

  @override
  String get headingNormal => 'Normal';

  @override
  String get headingLevel1 => 'Cabeçalho 1';

  @override
  String get headingLevel2 => 'Cabeçalho 2';

  @override
  String get headingLevel3 => 'Cabeçalho 3';

  @override
  String get headingLevel4 => 'Cabeçalho 4';

  @override
  String get headingLevel5 => 'Cabeçalho 5';

  @override
  String get headingLevel6 => 'Cabeçalho 6';

  @override
  String get addLinkDialogPasteLink => 'Colar uma ligação';

  @override
  String get addLinkDialogApply => 'Aplicar';

  @override
  String get linkDialogOpen => 'Abrir';

  @override
  String get linkDialogCopy => 'Copiar';

  @override
  String get linkDialogRemove => 'Remover';
}

/// The translations for Portuguese, as used in Brazil (`pt_BR`).
class FleatherLocalizationsPtBr extends FleatherLocalizationsPt {
  FleatherLocalizationsPtBr() : super('pt_BR');

  @override
  String get foregroundColorAutomatic => 'Automático';

  @override
  String get backgroundColorNoColor => 'Sem cor';

  @override
  String get headingNormal => 'Normal';

  @override
  String get headingLevel1 => 'Título 1';

  @override
  String get headingLevel2 => 'Título 2';

  @override
  String get headingLevel3 => 'Título 3';

  @override
  String get headingLevel4 => 'Título 4';

  @override
  String get headingLevel5 => 'Título 5';

  @override
  String get headingLevel6 => 'Título 6';

  @override
  String get addLinkDialogPasteLink => 'Cole um link';

  @override
  String get addLinkDialogApply => 'Aplicar';

  @override
  String get linkDialogOpen => 'Abrir';

  @override
  String get linkDialogCopy => 'Copiar';

  @override
  String get linkDialogRemove => 'Remover';
}
