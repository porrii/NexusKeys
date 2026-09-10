import '../entities/vault_item.dart';

/// Acceso CRUD a la bóveda cifrada. Todos los streams vuelven a emitir la
/// lista completa y actual después de cualquier llamada mutadora de abajo
/// — hay un único escritor (esta app, un proceso), así que volver a
/// consultar en cada escritura es más simple que un change-data-capture de
/// verdad y no es una preocupación de rendimiento relevante con el número
/// de filas de una bóveda.
///
/// [currentItems]/[currentTrash] e [itemsStream]/[trashStream] están
/// deliberadamente separados en vez de un único Stream que reproduce su
/// último valor a los nuevos suscriptores: montar esa reproducción a mano
/// con un generador `async*` compitiendo con un controller broadcast es un
/// footgun de verdad (una mutación que se ejecute de forma síncrona —
/// como todas las de aquí, `package:sqlite3` no tiene E/S asíncrona —
/// puede adelantarse al primer `yield` del propio generador y descartar
/// eventos en silencio). Un getter normal para el "ahora mismo" más un
/// stream normal de notificación de cambios evita eso por completo, y es
/// exactamente lo que quiere `StreamBuilder(initialData: ..., stream: ...)`
/// de todas formas.
abstract interface class VaultRepository {
  /// Elementos no borrados, los actualizados más recientemente primero, a
  /// fecha de la última mutación o [reload].
  List<VaultItem> get currentItems;

  /// Elementos que están ahora en la papelera (Papelera), los borrados más
  /// recientemente primero.
  List<VaultItem> get currentTrash;

  /// Emite la lista activa completa después de cada mutación y [reload].
  Stream<List<VaultItem>> get itemsStream;

  /// Emite la lista completa de la papelera después de cada mutación y
  /// [reload].
  Stream<List<VaultItem>> get trashStream;

  /// Inserta [draft] (su `id` se ignora) y lo devuelve tal y como se ha
  /// guardado de verdad — releído del almacenamiento en vez del propio
  /// [draft], ya que las marcas de tiempo se truncan a milisegundos al
  /// entrar en SQLite y [draft] puede llevar precisión de sub-milisegundo
  /// que nunca se guardó.
  Future<VaultItem> create(VaultItem draft);

  /// Guarda todos los campos de [item] excepto `id`/`createdAt`;
  /// `updatedAt` se refresca a ahora independientemente de lo que lleve
  /// [item].
  Future<void> update(VaultItem item);

  Future<void> setFavorite(int id, bool isFavorite);

  /// Borrado suave: mueve el elemento a la papelera sin borrarlo.
  Future<void> moveToTrash(int id);

  Future<void> restoreFromTrash(int id);

  /// Borra la fila. Solo válido para elementos que ya están en la
  /// papelera.
  Future<void> deletePermanently(int id);

  /// Vuelve a consultar [currentItems]/[currentTrash] y a re-emitir ambos
  /// streams contra la conexión de base de datos que [VaultSession] tenga
  /// en ese momento. Hay que llamarlo después de cada desbloqueo — no solo
  /// el primero en la vida de la app — o un re-desbloqueo tras un bloqueo
  /// seguiría sirviendo datos rancios de la sesión anterior.
  Future<void> reload();

  /// Libera los controllers de los streams. Llámalo cuando la bóveda se
  /// bloquea.
  void dispose();
}
