/// Nilai uang menggunakan integer Rupiah, tanpa pembulatan floating-point.
String formatRupiah(int amount) {
  final digits = amount.abs().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]}.',
  );
  return '${amount < 0 ? '-' : ''}Rp $digits';
}
