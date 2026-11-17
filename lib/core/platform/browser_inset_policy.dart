/// Use real CSS insets whenever supplied. Some installed iPhone PWAs report zero.
double resolveBrowserBottomInset(
    {required double reportedBottom,
    required bool isIosPhone,
    required bool standalone,
    required double screenWidth,
    required double screenHeight}) {
  if (reportedBottom > 0 || !isIosPhone || !standalone) return reportedBottom;
  final shortest = screenWidth < screenHeight ? screenWidth : screenHeight;
  final longest = screenWidth > screenHeight ? screenWidth : screenHeight;
  if (shortest <= 0 || shortest >= 600 || longest < 780) return reportedBottom;
  return screenWidth > screenHeight ? 21 : 34;
}
