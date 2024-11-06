const String lorem='''
Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.
''';
final List<String> loremList = lorem.split(' ');


List<String> getWords(int len){
  if(len > loremList.length){
    return loremList;
  }
  return loremList.getRange(0, len).toList();
}

String getText(int len){
  if(len > loremList.length){
    return lorem;
  }
  return loremList.getRange(0, len).join(' ');
}
