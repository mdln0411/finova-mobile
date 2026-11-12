import 'dart:convert';

import 'package:file_picker/file_picker.dart';

import '../domain/company.dart';

/// Hasil memilih logo: [svg] terisi jika valid, [error] jika ditolak.
/// Keduanya null berarti pengguna membatalkan.
typedef SvgLogoPick = ({String? svg, String? error});

Future<SvgLogoPick> pickSvgLogo() async {
  try {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['svg'],
    );
    if (file == null) return (svg: null, error: null);
    final size = await file.length();
    if (size != null && size > CompanyValidators.maxLogoBytes) {
      return (svg: null, error: 'Ukuran logo maksimal 50 KB.');
    }
    final String text;
    try {
      text = utf8.decode(await file.readAsBytes());
    } on FormatException {
      return (svg: null, error: 'File SVG harus berformat teks UTF-8.');
    }
    final error = CompanyValidators.logoSvg(text);
    return error == null ? (svg: text, error: null) : (svg: null, error: error);
  } catch (_) {
    return (svg: null, error: 'File logo belum dapat dibaca. Coba lagi.');
  }
}
