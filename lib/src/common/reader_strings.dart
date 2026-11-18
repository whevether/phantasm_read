import 'dart:ui' show Locale;

/// Replaceable built-in UI strings. Pass a custom instance to override.
///
/// Presets: [zh], [zhHant] (Traditional Chinese), [en], [th] (Thai), [vi] (Vietnamese), [id] (Indonesian),
/// [ms] (Malay) and [fil] (Filipino). Use [forLocale] / [forLanguageCode] to
/// pick one from the device or app locale.
class ReaderStrings {
  const ReaderStrings({
    this.autoLocale = false,
    this.bookmarks = '书签',
    this.imageLoadFailed = '图片加载失败',
    this.noReadableContent = '无可阅读内容',
    this.loadFailed = '加载失败',
    this.nextChapter = '下一章',
    this.previousChapter = '上一章',
    this.progress = '阅读进度',
    this.emptyDocument = '文档为空',
    this.noContent = '暂无内容',
    this.selectChapter = '选择章节',
    this.noToc = '暂无章节目录',
    this.searchFailed = '搜索失败',
    this.toggleToolbar = '显示或隐藏工具栏',
    this.orientation = '方向',
    this.fit = '适应',
    this.doublePage = '双页',
    this.doublePageOff = '关闭双页',
    this.doublePageSwitchHint = '双页（将切换为横向）',
    this.bookmark = '书签',
    this.bookmarkList = '书签列表',
    this.thumbnails = '缩略图',
    this.keepScreenOn = '不熄屏',
    this.volumeKeyPaging = '音量键翻页',
    this.volumeKeyPagingOff = '关闭音量键翻页',
    this.fullscreen = '全屏',
    this.exitFullscreen = '退出全屏',
    this.goToPageTitle = '跳转页码',
    this.goToPage = '跳页',
    this.cancel = '取消',
    this.confirm = '确定',
    this.autoScroll = '自动滚屏',
    this.tts = '朗读',
    this.audioPlay = '有声播放',
    this.audioPause = '有声暂停',
    this.undoInk = '撤销笔迹',
    this.clearInk = '清空笔迹',
    this.autoCrop = '自动裁边',
    this.autoCropOff = '关闭自动裁边',
    this.searchHint = '搜索…',
    this.lineHeight = '行距',
    this.pageMargin = '边距',
    this.letterSpacing = '字距',
    this.alignJustify = '两端',
    this.alignLeft = '左齐',
    this.systemFont = '系统',
    this.searchOutsideTrial = '另有 {n} 条结果在试读范围外',
    this.noResults = '没有结果',
    this.pageOfFormat = '第 {page} / {total} 页',
    this.pageNFormat = '第 {n} 页',
    this.paragraphNFormat = '第 {n} 段',
    this.retry = '重试',
    this.delete = '删除',
    this.previousPage = '上一页',
    this.nextPage = '下一页',
    this.search = '搜索',
    this.toc = '目录',
    this.highlight = '高亮',
    this.addBookmark = '添加书签',
    this.removeBookmark = '移除书签',
    this.fitContain = '适应屏幕',
    this.fitWidth = '适应宽度',
    this.fitHeight = '适应高度',
    this.readingMode = '阅读模式',
    this.modeHorizontal = '横向翻页',
    this.modeVertical = '纵向翻页',
    this.modeWebtoon = '条漫',
    this.epubUnsupported = 'EPUB 仅支持 Android、iOS 与 macOS，当前平台请使用文本/漫画/PDF。',
    this.pdfEncrypted = 'PDF 已加密或无法解析',
    this.brightness = '亮度',
    this.fontSize = '字号',
    this.copy = '复制',
    this.copied = '已复制',
    this.note = '笔记',
    this.save = '保存',
    this.selectTextFirst = '请先在正文中选中文字',
    this.swipeSensitivity = '滑动灵敏度',
  });

  /// Marker instance: the readers pick the preset matching the ambient
  /// [Locale] (see [resolveFor]). This is the default for every reader's
  /// `strings` parameter; pass a concrete preset to pin a language.
  static const ReaderStrings auto = ReaderStrings(autoLocale: true);

  /// Whether this instance is the [auto] marker.
  final bool autoLocale;

  /// Returns [forLocale] for the [auto] marker (English when the locale is
  /// unknown or unsupported), otherwise this instance unchanged.
  ReaderStrings resolveFor(Locale? locale) =>
      autoLocale ? forLocale(locale) : this;

  /// Simplified Chinese.
  static const ReaderStrings zh = ReaderStrings();

  /// English.
  static const ReaderStrings en = ReaderStrings(
    bookmarks: 'Bookmarks',
    imageLoadFailed: 'Failed to load image',
    noReadableContent: 'No readable content',
    loadFailed: 'Load failed',
    nextChapter: 'Next chapter',
    previousChapter: 'Previous chapter',
    progress: 'Reading progress',
    emptyDocument: 'Empty document',
    noContent: 'No content',
    selectChapter: 'Select chapter',
    noToc: 'No table of contents',
    searchFailed: 'Search failed',
    toggleToolbar: 'Show or hide toolbar',
    orientation: 'Reading mode',
    fit: 'Fit',
    doublePage: 'Double page',
    doublePageOff: 'Turn off double page',
    doublePageSwitchHint: 'Double page (switches to horizontal)',
    bookmark: 'Bookmark',
    bookmarkList: 'Bookmark list',
    thumbnails: 'Thumbnails',
    keepScreenOn: 'Keep screen on',
    volumeKeyPaging: 'Volume key paging',
    volumeKeyPagingOff: 'Turn off volume key paging',
    fullscreen: 'Fullscreen',
    exitFullscreen: 'Exit fullscreen',
    goToPageTitle: 'Go to page',
    goToPage: 'Go to',
    cancel: 'Cancel',
    confirm: 'OK',
    autoScroll: 'Auto scroll',
    tts: 'Read aloud',
    audioPlay: 'Play audio',
    audioPause: 'Pause audio',
    undoInk: 'Undo stroke',
    clearInk: 'Clear strokes',
    autoCrop: 'Auto-crop margins',
    autoCropOff: 'Turn off auto-crop',
    searchHint: 'Search…',
    lineHeight: 'Line spacing',
    pageMargin: 'Margin',
    letterSpacing: 'Letter spacing',
    alignJustify: 'Justify',
    alignLeft: 'Left',
    systemFont: 'System',
    searchOutsideTrial: '{n} more results are outside the preview',
    noResults: 'No results',
    pageOfFormat: 'Page {page} of {total}',
    pageNFormat: 'Page {n}',
    paragraphNFormat: 'Paragraph {n}',
    retry: 'Retry',
    delete: 'Delete',
    previousPage: 'Previous page',
    nextPage: 'Next page',
    search: 'Search',
    toc: 'Table of contents',
    highlight: 'Highlight',
    addBookmark: 'Add bookmark',
    removeBookmark: 'Remove bookmark',
    fitContain: 'Fit to screen',
    fitWidth: 'Fit width',
    fitHeight: 'Fit height',
    readingMode: 'Reading mode',
    modeHorizontal: 'Horizontal',
    modeVertical: 'Vertical',
    modeWebtoon: 'Webtoon',
    epubUnsupported: 'EPUB is supported on Android, iOS and macOS only. Use text, comic or PDF on this platform.',
    pdfEncrypted: 'The PDF is encrypted or cannot be parsed',
    brightness: 'Brightness',
    fontSize: 'Font size',
    copy: 'Copy',
    copied: 'Copied',
    note: 'Note',
    save: 'Save',
    selectTextFirst: 'Select some text first',
    swipeSensitivity: 'Swipe sensitivity',
  );

  /// Thai.
  static const ReaderStrings th = ReaderStrings(
    bookmarks: 'ที่คั่นหนังสือ',
    imageLoadFailed: 'โหลดรูปภาพไม่สำเร็จ',
    noReadableContent: 'ไม่มีเนื้อหาที่อ่านได้',
    loadFailed: 'โหลดไม่สำเร็จ',
    nextChapter: 'บทถัดไป',
    previousChapter: 'บทก่อนหน้า',
    progress: 'ความคืบหน้าการอ่าน',
    emptyDocument: 'เอกสารว่างเปล่า',
    noContent: 'ไม่มีเนื้อหา',
    selectChapter: 'เลือกบท',
    noToc: 'ไม่มีสารบัญ',
    searchFailed: 'ค้นหาไม่สำเร็จ',
    toggleToolbar: 'แสดงหรือซ่อนแถบเครื่องมือ',
    orientation: 'ทิศทางการอ่าน',
    fit: 'ปรับขนาดภาพ',
    doublePage: 'สองหน้า',
    doublePageOff: 'ปิดโหมดสองหน้า',
    doublePageSwitchHint: 'สองหน้า (จะสลับเป็นแนวนอน)',
    bookmark: 'ที่คั่นหนังสือ',
    bookmarkList: 'รายการที่คั่นหนังสือ',
    thumbnails: 'ภาพขนาดย่อ',
    keepScreenOn: 'เปิดหน้าจอค้าง',
    volumeKeyPaging: 'เปลี่ยนหน้าด้วยปุ่มเสียง',
    volumeKeyPagingOff: 'ปิดการเปลี่ยนหน้าด้วยปุ่มเสียง',
    fullscreen: 'เต็มหน้าจอ',
    exitFullscreen: 'ออกจากเต็มหน้าจอ',
    goToPageTitle: 'ไปยังหน้า',
    goToPage: 'ไปที่',
    cancel: 'ยกเลิก',
    confirm: 'ตกลง',
    autoScroll: 'เลื่อนอัตโนมัติ',
    tts: 'อ่านออกเสียง',
    audioPlay: 'เล่นเสียง',
    audioPause: 'หยุดเสียงชั่วคราว',
    undoInk: 'ย้อนกลับเส้นที่วาด',
    clearInk: 'ล้างเส้นที่วาด',
    autoCrop: 'ตัดขอบอัตโนมัติ',
    autoCropOff: 'ปิดการตัดขอบอัตโนมัติ',
    searchHint: 'ค้นหา…',
    lineHeight: 'ระยะบรรทัด',
    pageMargin: 'ระยะขอบ',
    letterSpacing: 'ระยะตัวอักษร',
    alignJustify: 'ชิดสองด้าน',
    alignLeft: 'ชิดซ้าย',
    systemFont: 'ระบบ',
    searchOutsideTrial: 'มีผลลัพธ์อีก {n} รายการนอกช่วงทดลองอ่าน',
    noResults: 'ไม่พบผลลัพธ์',
    pageOfFormat: 'หน้า {page} จาก {total}',
    pageNFormat: 'หน้า {n}',
    paragraphNFormat: 'ย่อหน้า {n}',
    retry: 'ลองอีกครั้ง',
    delete: 'ลบ',
    previousPage: 'หน้าก่อนหน้า',
    nextPage: 'หน้าถัดไป',
    search: 'ค้นหา',
    toc: 'สารบัญ',
    highlight: 'ไฮไลต์',
    addBookmark: 'เพิ่มที่คั่นหนังสือ',
    removeBookmark: 'ลบที่คั่นหนังสือ',
    fitContain: 'พอดีหน้าจอ',
    fitWidth: 'พอดีความกว้าง',
    fitHeight: 'พอดีความสูง',
    readingMode: 'โหมดการอ่าน',
    modeHorizontal: 'แนวนอน',
    modeVertical: 'แนวตั้ง',
    modeWebtoon: 'เว็บตูน',
    epubUnsupported: 'EPUB รองรับเฉพาะ Android, iOS และ macOS บนแพลตฟอร์มนี้ให้ใช้ข้อความ การ์ตูน หรือ PDF',
    pdfEncrypted: 'PDF ถูกเข้ารหัสหรือไม่สามารถอ่านได้',
    brightness: 'ความสว่าง',
    fontSize: 'ขนาดตัวอักษร',
    copy: 'คัดลอก',
    copied: 'คัดลอกแล้ว',
    note: 'บันทึกย่อ',
    save: 'บันทึก',
    selectTextFirst: 'เลือกข้อความก่อน',
    swipeSensitivity: 'ความไวการปัด',
  );

  /// Vietnamese.
  static const ReaderStrings vi = ReaderStrings(
    bookmarks: 'Dấu trang',
    imageLoadFailed: 'Không tải được ảnh',
    noReadableContent: 'Không có nội dung có thể đọc',
    loadFailed: 'Không tải được',
    nextChapter: 'Chương sau',
    previousChapter: 'Chương trước',
    progress: 'Tiến độ đọc',
    emptyDocument: 'Tài liệu trống',
    noContent: 'Không có nội dung',
    selectChapter: 'Chọn chương',
    noToc: 'Không có mục lục',
    searchFailed: 'Tìm kiếm thất bại',
    toggleToolbar: 'Hiện hoặc ẩn thanh công cụ',
    orientation: 'Chế độ đọc',
    fit: 'Vừa khung',
    doublePage: 'Hai trang',
    doublePageOff: 'Tắt chế độ hai trang',
    doublePageSwitchHint: 'Hai trang (sẽ chuyển sang chiều ngang)',
    bookmark: 'Dấu trang',
    bookmarkList: 'Danh sách dấu trang',
    thumbnails: 'Ảnh thu nhỏ',
    keepScreenOn: 'Giữ màn hình sáng',
    volumeKeyPaging: 'Lật trang bằng phím âm lượng',
    volumeKeyPagingOff: 'Tắt lật trang bằng phím âm lượng',
    fullscreen: 'Toàn màn hình',
    exitFullscreen: 'Thoát toàn màn hình',
    goToPageTitle: 'Đi đến trang',
    goToPage: 'Đi',
    cancel: 'Hủy',
    confirm: 'OK',
    autoScroll: 'Tự cuộn',
    tts: 'Đọc thành tiếng',
    audioPlay: 'Phát âm thanh',
    audioPause: 'Tạm dừng âm thanh',
    undoInk: 'Hoàn tác nét vẽ',
    clearInk: 'Xóa nét vẽ',
    autoCrop: 'Tự động cắt viền',
    autoCropOff: 'Tắt tự động cắt viền',
    searchHint: 'Tìm kiếm…',
    lineHeight: 'Giãn dòng',
    pageMargin: 'Lề',
    letterSpacing: 'Giãn chữ',
    alignJustify: 'Căn đều',
    alignLeft: 'Căn trái',
    systemFont: 'Hệ thống',
    searchOutsideTrial: 'Còn {n} kết quả nằm ngoài phần đọc thử',
    noResults: 'Không có kết quả',
    pageOfFormat: 'Trang {page}/{total}',
    pageNFormat: 'Trang {n}',
    paragraphNFormat: 'Đoạn {n}',
    retry: 'Thử lại',
    delete: 'Xóa',
    previousPage: 'Trang trước',
    nextPage: 'Trang sau',
    search: 'Tìm kiếm',
    toc: 'Mục lục',
    highlight: 'Đánh dấu',
    addBookmark: 'Thêm dấu trang',
    removeBookmark: 'Xóa dấu trang',
    fitContain: 'Vừa màn hình',
    fitWidth: 'Vừa chiều rộng',
    fitHeight: 'Vừa chiều cao',
    readingMode: 'Chế độ đọc',
    modeHorizontal: 'Ngang',
    modeVertical: 'Dọc',
    modeWebtoon: 'Webtoon',
    epubUnsupported: 'EPUB chỉ hỗ trợ Android, iOS và macOS. Trên nền tảng này hãy dùng văn bản, truyện tranh hoặc PDF.',
    pdfEncrypted: 'PDF bị mã hóa hoặc không thể đọc được',
    brightness: 'Độ sáng',
    fontSize: 'Cỡ chữ',
    copy: 'Sao chép',
    copied: 'Đã sao chép',
    note: 'Ghi chú',
    save: 'Lưu',
    selectTextFirst: 'Hãy chọn văn bản trước',
    swipeSensitivity: 'Độ nhạy vuốt',
  );

  /// Indonesian (Bahasa Indonesia).
  static const ReaderStrings id = ReaderStrings(
    bookmarks: 'Penanda',
    imageLoadFailed: 'Gagal memuat gambar',
    noReadableContent: 'Tidak ada konten yang dapat dibaca',
    loadFailed: 'Gagal memuat',
    nextChapter: 'Bab berikutnya',
    previousChapter: 'Bab sebelumnya',
    progress: 'Progres membaca',
    emptyDocument: 'Dokumen kosong',
    noContent: 'Tidak ada konten',
    selectChapter: 'Pilih bab',
    noToc: 'Tidak ada daftar isi',
    searchFailed: 'Pencarian gagal',
    toggleToolbar: 'Tampilkan atau sembunyikan bilah alat',
    orientation: 'Mode baca',
    fit: 'Sesuaikan ukuran',
    doublePage: 'Dua halaman',
    doublePageOff: 'Matikan dua halaman',
    doublePageSwitchHint: 'Dua halaman (beralih ke horizontal)',
    bookmark: 'Penanda',
    bookmarkList: 'Daftar penanda',
    thumbnails: 'Gambar mini',
    keepScreenOn: 'Layar tetap menyala',
    volumeKeyPaging: 'Ganti halaman dengan tombol volume',
    volumeKeyPagingOff: 'Matikan ganti halaman dengan tombol volume',
    fullscreen: 'Layar penuh',
    exitFullscreen: 'Keluar layar penuh',
    goToPageTitle: 'Ke halaman',
    goToPage: 'Buka halaman',
    cancel: 'Batal',
    confirm: 'OK',
    autoScroll: 'Gulir otomatis',
    tts: 'Baca nyaring',
    audioPlay: 'Putar audio',
    audioPause: 'Jeda audio',
    undoInk: 'Urungkan coretan',
    clearInk: 'Hapus coretan',
    autoCrop: 'Pangkas tepi otomatis',
    autoCropOff: 'Matikan pangkas tepi otomatis',
    searchHint: 'Cari…',
    lineHeight: 'Jarak baris',
    pageMargin: 'Margin',
    letterSpacing: 'Jarak huruf',
    alignJustify: 'Rata kiri-kanan',
    alignLeft: 'Rata kiri',
    systemFont: 'Sistem',
    searchOutsideTrial: '{n} hasil lagi berada di luar pratinjau',
    noResults: 'Tidak ada hasil',
    pageOfFormat: 'Halaman {page} dari {total}',
    pageNFormat: 'Halaman {n}',
    paragraphNFormat: 'Paragraf {n}',
    retry: 'Coba lagi',
    delete: 'Hapus',
    previousPage: 'Halaman sebelumnya',
    nextPage: 'Halaman berikutnya',
    search: 'Cari',
    toc: 'Daftar isi',
    highlight: 'Sorot',
    addBookmark: 'Tambah bookmark',
    removeBookmark: 'Hapus bookmark',
    fitContain: 'Sesuaikan layar',
    fitWidth: 'Sesuaikan lebar',
    fitHeight: 'Sesuaikan tinggi',
    readingMode: 'Mode baca',
    modeHorizontal: 'Horizontal',
    modeVertical: 'Vertikal',
    modeWebtoon: 'Webtoon',
    epubUnsupported: 'EPUB hanya didukung di Android, iOS, dan macOS. Gunakan teks, komik, atau PDF di platform ini.',
    pdfEncrypted: 'PDF terenkripsi atau tidak dapat dibaca',
    brightness: 'Kecerahan',
    fontSize: 'Ukuran font',
    copy: 'Salin',
    copied: 'Disalin',
    note: 'Catatan',
    save: 'Simpan',
    selectTextFirst: 'Pilih teks terlebih dahulu',
    swipeSensitivity: 'Sensitivitas gesek',
  );

  /// Malay (Bahasa Melayu).
  static const ReaderStrings ms = ReaderStrings(
    bookmarks: 'Penanda buku',
    imageLoadFailed: 'Gagal memuatkan imej',
    noReadableContent: 'Tiada kandungan yang boleh dibaca',
    loadFailed: 'Gagal dimuatkan',
    nextChapter: 'Bab seterusnya',
    previousChapter: 'Bab sebelumnya',
    progress: 'Kemajuan bacaan',
    emptyDocument: 'Dokumen kosong',
    noContent: 'Tiada kandungan',
    selectChapter: 'Pilih bab',
    noToc: 'Tiada jadual kandungan',
    searchFailed: 'Carian gagal',
    toggleToolbar: 'Tunjuk atau sembunyi bar alat',
    orientation: 'Mod bacaan',
    fit: 'Muatkan ke skrin',
    doublePage: 'Dua halaman',
    doublePageOff: 'Matikan dua halaman',
    doublePageSwitchHint: 'Dua halaman (bertukar ke mendatar)',
    bookmark: 'Penanda buku',
    bookmarkList: 'Senarai penanda buku',
    thumbnails: 'Imej kecil',
    keepScreenOn: 'Kekalkan skrin menyala',
    volumeKeyPaging: 'Tukar halaman dengan butang kelantangan',
    volumeKeyPagingOff: 'Matikan tukar halaman dengan butang kelantangan',
    fullscreen: 'Skrin penuh',
    exitFullscreen: 'Keluar skrin penuh',
    goToPageTitle: 'Pergi ke halaman',
    goToPage: 'Pergi ke halaman',
    cancel: 'Batal',
    confirm: 'OK',
    autoScroll: 'Tatal automatik',
    tts: 'Baca dengan lantang',
    audioPlay: 'Main audio',
    audioPause: 'Jeda audio',
    undoInk: 'Buat asal coretan',
    clearInk: 'Padam coretan',
    autoCrop: 'Pangkas tepi automatik',
    autoCropOff: 'Matikan pangkas tepi automatik',
    searchHint: 'Cari…',
    lineHeight: 'Jarak baris',
    pageMargin: 'Margin',
    letterSpacing: 'Jarak huruf',
    alignJustify: 'Rata kiri-kanan',
    alignLeft: 'Rata kiri',
    systemFont: 'Sistem',
    searchOutsideTrial: '{n} hasil lagi berada di luar pratonton',
    noResults: 'Tiada hasil',
    pageOfFormat: 'Halaman {page} daripada {total}',
    pageNFormat: 'Halaman {n}',
    paragraphNFormat: 'Perenggan {n}',
    retry: 'Cuba lagi',
    delete: 'Padam',
    previousPage: 'Halaman sebelumnya',
    nextPage: 'Halaman seterusnya',
    search: 'Cari',
    toc: 'Kandungan',
    highlight: 'Serlahkan',
    addBookmark: 'Tambah penanda buku',
    removeBookmark: 'Alih keluar penanda buku',
    fitContain: 'Muat skrin',
    fitWidth: 'Muat lebar',
    fitHeight: 'Muat tinggi',
    readingMode: 'Mod bacaan',
    modeHorizontal: 'Mendatar',
    modeVertical: 'Menegak',
    modeWebtoon: 'Webtoon',
    epubUnsupported: 'EPUB hanya disokong pada Android, iOS dan macOS. Gunakan teks, komik atau PDF pada platform ini.',
    pdfEncrypted: 'PDF disulitkan atau tidak dapat dibaca',
    brightness: 'Kecerahan',
    fontSize: 'Saiz fon',
    copy: 'Salin',
    copied: 'Disalin',
    note: 'Nota',
    save: 'Simpan',
    selectTextFirst: 'Pilih teks dahulu',
    swipeSensitivity: 'Kepekaan leret',
  );

  /// Filipino.
  static const ReaderStrings fil = ReaderStrings(
    bookmarks: 'Mga bookmark',
    imageLoadFailed: 'Hindi ma-load ang larawan',
    noReadableContent: 'Walang nababasang nilalaman',
    loadFailed: 'Hindi na-load',
    nextChapter: 'Susunod na kabanata',
    previousChapter: 'Nakaraang kabanata',
    progress: 'Progreso ng pagbabasa',
    emptyDocument: 'Walang laman ang dokumento',
    noContent: 'Walang nilalaman',
    selectChapter: 'Pumili ng kabanata',
    noToc: 'Walang talaan ng nilalaman',
    searchFailed: 'Nabigo ang paghahanap',
    toggleToolbar: 'Ipakita o itago ang toolbar',
    orientation: 'Mode ng pagbabasa',
    fit: 'Isaayos ang laki',
    doublePage: 'Dalawang pahina',
    doublePageOff: 'I-off ang dalawang pahina',
    doublePageSwitchHint: 'Dalawang pahina (lilipat sa pahalang)',
    bookmark: 'Bookmark',
    bookmarkList: 'Listahan ng bookmark',
    thumbnails: 'Mga thumbnail',
    keepScreenOn: 'Panatilihing bukas ang screen',
    volumeKeyPaging: 'Magpalit ng pahina gamit ang volume key',
    volumeKeyPagingOff: 'I-off ang pagpapalit ng pahina gamit ang volume key',
    fullscreen: 'Buong screen',
    exitFullscreen: 'Lumabas sa buong screen',
    goToPageTitle: 'Pumunta sa pahina',
    goToPage: 'Pumunta sa pahina',
    cancel: 'Kanselahin',
    confirm: 'OK',
    autoScroll: 'Awtomatikong pag-scroll',
    tts: 'Basahin nang malakas',
    audioPlay: 'I-play ang audio',
    audioPause: 'I-pause ang audio',
    undoInk: 'I-undo ang guhit',
    clearInk: 'Burahin ang mga guhit',
    autoCrop: 'Awtomatikong i-crop ang gilid',
    autoCropOff: 'I-off ang awtomatikong pag-crop',
    searchHint: 'Maghanap…',
    lineHeight: 'Espasyo ng linya',
    pageMargin: 'Margin',
    letterSpacing: 'Espasyo ng letra',
    alignJustify: 'Justify',
    alignLeft: 'Kaliwa',
    systemFont: 'System',
    searchOutsideTrial: '{n} pang resulta ay nasa labas ng preview',
    noResults: 'Walang resulta',
    pageOfFormat: 'Pahina {page} ng {total}',
    pageNFormat: 'Pahina {n}',
    paragraphNFormat: 'Talata {n}',
    retry: 'Subukang muli',
    delete: 'Burahin',
    previousPage: 'Nakaraang pahina',
    nextPage: 'Susunod na pahina',
    search: 'Maghanap',
    toc: 'Talaan ng nilalaman',
    highlight: 'I-highlight',
    addBookmark: 'Magdagdag ng bookmark',
    removeBookmark: 'Alisin ang bookmark',
    fitContain: 'Akma sa screen',
    fitWidth: 'Akma sa lapad',
    fitHeight: 'Akma sa taas',
    readingMode: 'Mode ng pagbabasa',
    modeHorizontal: 'Pahalang',
    modeVertical: 'Patayo',
    modeWebtoon: 'Webtoon',
    epubUnsupported: 'Sinusuportahan lang ang EPUB sa Android, iOS at macOS. Gumamit ng text, comic o PDF sa platform na ito.',
    pdfEncrypted: 'Naka-encrypt ang PDF o hindi mabasa',
    brightness: 'Liwanag',
    fontSize: 'Laki ng font',
    copy: 'Kopyahin',
    copied: 'Nakopya',
    note: 'Tala',
    save: 'I-save',
    selectTextFirst: 'Pumili muna ng teksto',
    swipeSensitivity: 'Sensitibo ng swipe',
  );

  /// Traditional Chinese.
  static const ReaderStrings zhHant = ReaderStrings(
    bookmarks: '書籤',
    imageLoadFailed: '圖片載入失敗',
    noReadableContent: '無可閱讀內容',
    loadFailed: '載入失敗',
    nextChapter: '下一章',
    previousChapter: '上一章',
    progress: '閱讀進度',
    emptyDocument: '文件為空',
    noContent: '暫無內容',
    selectChapter: '選擇章節',
    noToc: '暫無章節目錄',
    searchFailed: '搜尋失敗',
    toggleToolbar: '顯示或隱藏工具列',
    orientation: '方向',
    fit: '適應',
    doublePage: '雙頁',
    doublePageOff: '關閉雙頁',
    doublePageSwitchHint: '雙頁（將切換為橫向）',
    bookmark: '書籤',
    bookmarkList: '書籤列表',
    thumbnails: '縮圖',
    keepScreenOn: '不熄屏',
    volumeKeyPaging: '音量鍵翻頁',
    volumeKeyPagingOff: '關閉音量鍵翻頁',
    fullscreen: '全螢幕',
    exitFullscreen: '退出全螢幕',
    goToPageTitle: '跳轉頁碼',
    goToPage: '跳頁',
    cancel: '取消',
    confirm: '確定',
    autoScroll: '自動捲動',
    tts: '朗讀',
    audioPlay: '有聲播放',
    audioPause: '有聲暫停',
    undoInk: '復原筆跡',
    clearInk: '清空筆跡',
    autoCrop: '自動裁邊',
    autoCropOff: '關閉自動裁邊',
    searchHint: '搜尋…',
    lineHeight: '行距',
    pageMargin: '邊距',
    letterSpacing: '字距',
    alignJustify: '兩端',
    alignLeft: '左齊',
    systemFont: '系統',
    searchOutsideTrial: '另有 {n} 筆結果在試讀範圍外',
    noResults: '沒有結果',
    pageOfFormat: '第 {page} / {total} 頁',
    pageNFormat: '第 {n} 頁',
    paragraphNFormat: '第 {n} 段',
    retry: '重試',
    delete: '刪除',
    previousPage: '上一頁',
    nextPage: '下一頁',
    search: '搜尋',
    toc: '目錄',
    highlight: '標註',
    addBookmark: '加入書籤',
    removeBookmark: '移除書籤',
    fitContain: '適應螢幕',
    fitWidth: '適應寬度',
    fitHeight: '適應高度',
    readingMode: '閱讀模式',
    modeHorizontal: '橫向翻頁',
    modeVertical: '縱向翻頁',
    modeWebtoon: '條漫',
    epubUnsupported: 'EPUB 僅支援 Android、iOS 與 macOS，目前平台請使用文字／漫畫／PDF。',
    pdfEncrypted: 'PDF 已加密或無法解析',
    brightness: '亮度',
    fontSize: '字級',
    copy: '複製',
    copied: '已複製',
    note: '筆記',
    save: '儲存',
    selectTextFirst: '請先在內文中選取文字',
    swipeSensitivity: '滑動靈敏度',
  );

  /// Presets keyed by language code.
  static const Map<String, ReaderStrings> presets = {
    'zh': zh,
    'zh-hant': zhHant,
    'en': en,
    'th': th,
    'vi': vi,
    'id': id,
    'ms': ms,
    'fil': fil,
  };

  /// Legacy / alternative ISO codes mapped to a preset key.
  static const Map<String, String> _aliases = {'in': 'id', 'tl': 'fil'};

  /// Returns the preset for [code] (e.g. `th`, `vi`, `fil`, `zh-CN`,
  /// `id_ID`), or [fallback] when the language is not supported.
  static ReaderStrings forLanguageCode(
    String? code, {
    ReaderStrings fallback = en,
  }) {
    if (code == null || code.isEmpty) return fallback;
    final parts = code.toLowerCase().split(RegExp('[-_]'));
    final lang = parts.first;
    if (lang == 'zh') {
      // zh-Hant / zh-TW / zh-HK / zh-MO use Traditional characters.
      final traditional = parts
          .skip(1)
          .any((p) => const {'hant', 'tw', 'hk', 'mo'}.contains(p));
      return traditional ? zhHant : zh;
    }
    return presets[_aliases[lang] ?? lang] ?? fallback;
  }

  /// Returns the preset for [locale], or [fallback] when unsupported.
  /// Traditional Chinese (script `Hant` or region TW/HK/MO) gets [zhHant].
  static ReaderStrings forLocale(
    Locale? locale, {
    ReaderStrings fallback = en,
  }) {
    if (locale == null) return fallback;
    if (locale.languageCode.toLowerCase() == 'zh') {
      final script = locale.scriptCode?.toLowerCase();
      final region = locale.countryCode?.toUpperCase();
      final hant =
          script == 'hant' ||
          (script == null && const {'TW', 'HK', 'MO'}.contains(region));
      return hant ? zhHant : zh;
    }
    return forLanguageCode(locale.languageCode, fallback: fallback);
  }

  final String bookmarks;
  final String imageLoadFailed;
  final String noReadableContent;
  final String loadFailed;
  final String nextChapter;
  final String previousChapter;
  final String progress;
  final String emptyDocument;
  final String noContent;
  final String selectChapter;
  final String noToc;
  final String searchFailed;
  final String toggleToolbar;
  final String orientation;
  final String fit;
  final String doublePage;
  final String doublePageOff;
  final String doublePageSwitchHint;
  final String bookmark;
  final String bookmarkList;
  final String thumbnails;
  final String keepScreenOn;
  final String volumeKeyPaging;
  final String volumeKeyPagingOff;
  final String fullscreen;
  final String exitFullscreen;
  final String goToPageTitle;
  final String goToPage;
  final String cancel;
  final String confirm;
  final String autoScroll;
  final String tts;
  final String audioPlay;
  final String audioPause;
  final String undoInk;
  final String clearInk;
  final String autoCrop;
  final String autoCropOff;
  final String searchHint;
  final String lineHeight;
  final String pageMargin;
  final String letterSpacing;
  final String alignJustify;
  final String alignLeft;
  final String systemFont;
  final String searchOutsideTrial;
  final String noResults;
  final String pageOfFormat;
  final String pageNFormat;
  final String paragraphNFormat;
  final String retry;
  final String delete;
  final String previousPage;
  final String nextPage;
  final String search;
  final String toc;
  final String highlight;
  final String addBookmark;
  final String removeBookmark;
  final String fitContain;
  final String fitWidth;
  final String fitHeight;
  final String readingMode;
  final String modeHorizontal;
  final String modeVertical;
  final String modeWebtoon;
  final String epubUnsupported;
  final String pdfEncrypted;
  final String brightness;
  final String fontSize;
  final String copy;
  final String copied;
  final String note;
  final String save;
  final String selectTextFirst;
  final String swipeSensitivity;

  /// "{n} more results are outside the preview" with [n] filled in.
  String outsideTrial(int n) => searchOutsideTrial.replaceAll('{n}', '$n');

  /// "Page 3 of 10" style label (1-based [page]).
  String pageOf(int page, int total) => pageOfFormat
      .replaceAll('{page}', '$page')
      .replaceAll('{total}', '$total');

  /// "Page 3" style label (1-based [n]).
  String pageN(int n) => pageNFormat.replaceAll('{n}', '$n');

  /// "Paragraph 3" style label (1-based [n]).
  String paragraphN(int n) => paragraphNFormat.replaceAll('{n}', '$n');
}
