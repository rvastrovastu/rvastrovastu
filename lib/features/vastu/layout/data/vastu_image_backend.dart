/// Where Vastu plan pictures are kept: the app's documents folder on
/// phones and desktops, the browser's IndexedDB on the web.
library;

export 'vastu_image_backend_io.dart'
    if (dart.library.js_interop) 'vastu_image_backend_web.dart';
