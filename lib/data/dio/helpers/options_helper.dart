import 'package:dio/dio.dart';

Options withAccessToken() => Options(extra: {'requiresAccessToken': true});

Options withRefreshToken() => Options(extra: {'requiresRefreshToken': true});

Options withAuth({bool access = false, bool refresh = false}) => Options(
  extra: {
    if (access) 'requiresAccessToken': true,
    if (refresh) 'requiresRefreshToken': true,
  },
);
