import 'package:timeago/timeago.dart';

class MyMessages implements LookupMessages {
  @override String prefixAgo() => '';
  @override String prefixFromNow() => '';
  @override String suffixAgo() => 'အလိုက';
  @override String suffixFromNow() => 'မှ';
  @override String lessThanOneMinute(int seconds) => 'ယခုလေးတင်';
  @override String aboutAMinute(int minutes) => 'လွန်ခဲ့သော ၁ မိနစ်ခန့်';
  @override String minutes(int minutes) => 'လွန်ခဲ့သော $minutes မိနစ်';
  @override String aboutAnHour(int minutes) => 'လွန်ခဲ့သော ၁ နာရီခန့်';
  @override String hours(int hours) => 'လွန်ခဲ့သော $hours နာရီ';
  @override String aDay(int hours) => 'လွန်ခဲ့သော ၁ ရက်';
  @override String days(int days) => 'လွန်ခဲ့သော $days ရက်';
  @override String aboutAMonth(int days) => 'လွန်ခဲ့သော ၁ လခန့်';
  @override String months(int months) => 'လွန်ခဲ့သော $months လ';
  @override String aboutAYear(int year) => 'လွန်ခဲ့သော ၁ နှစ်ခန့်';
  @override String years(int years) => 'လွန်ခဲ့သော $years နှစ်';
  @override String wordSeparator() => ' ';
}
