// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get languages => 'Языки';

  @override
  String get continueButton => 'Продолжить';

  @override
  String get save => 'Сохранить';

  @override
  String get changeLanguage => 'Изменить Язык';

  @override
  String get welcomeToBrainBooster => 'Добро пожаловать в Brain Booster';

  @override
  String get pleaseFillDetails =>
      'Пожалуйста, заполните свои данные для продолжения';

  @override
  String get firstName => 'Имя';

  @override
  String get enterFirstName => 'Введите ваше имя';

  @override
  String get lastName => 'Фамилия';

  @override
  String get enterLastName => 'Введите вашу фамилию';

  @override
  String get birthdate => 'Дата рождения';

  @override
  String get selectBirthdate => 'Выберите дату рождения';

  @override
  String get iAccept => 'Я принимаю';

  @override
  String get termsAndConditions => 'Условия использования';

  @override
  String get pleaseAcceptTerms => 'Пожалуйста, примите Условия использования';

  @override
  String get pleaseEnterFirstName => 'Пожалуйста, введите ваше имя';

  @override
  String get pleaseEnterLastName => 'Пожалуйста, введите вашу фамилию';

  @override
  String get pleaseSelectBirthdate => 'Пожалуйста, выберите дату рождения';
}
