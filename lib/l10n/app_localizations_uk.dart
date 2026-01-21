// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get languages => 'Мови';

  @override
  String get continueButton => 'Продовжити';

  @override
  String get save => 'Зберегти';

  @override
  String get changeLanguage => 'Змінити Мову';

  @override
  String get welcomeToBrainBooster => 'Ласкаво просимо до Brain Booster';

  @override
  String get pleaseFillDetails =>
      'Будь ласка, заповніть свої дані для продовження';

  @override
  String get firstName => 'Ім\'я';

  @override
  String get enterFirstName => 'Введіть ваше ім\'я';

  @override
  String get lastName => 'Прізвище';

  @override
  String get enterLastName => 'Введіть ваше прізвище';

  @override
  String get birthdate => 'Дата народження';

  @override
  String get selectBirthdate => 'Виберіть дату народження';

  @override
  String get iAccept => 'Я приймаю';

  @override
  String get termsAndConditions => 'Умови використання';

  @override
  String get pleaseAcceptTerms => 'Будь ласка, прийміть Умови використання';

  @override
  String get pleaseEnterFirstName => 'Будь ласка, введіть ваше ім\'я';

  @override
  String get pleaseEnterLastName => 'Будь ласка, введіть ваше прізвище';

  @override
  String get pleaseSelectBirthdate => 'Будь ласка, виберіть дату народження';
}
