import '../../../core/database/app_database.dart';
import '../models/geofence_models.dart';

typedef UtcNow = DateTime Function();

class GeofencesRepository {
  GeofencesRepository(this._database, {UtcNow? utcNow})
    : _utcNow = utcNow ?? (() => DateTime.now().toUtc());

  final AppDatabase _database;
  final UtcNow _utcNow;

  Future<GeofenceManagementSnapshot> fetchManagementSnapshot() async {
    final activeRows = await _database.query(_activeGeofencesSql());
    final inactiveRows = await _database.query(_inactiveGeofencesSql());
    final countRows = await _database.query(_vehicleCountsSql());

    return GeofenceManagementSnapshot(
      activeGeofences: _mapGeofences(activeRows),
      inactiveGeofences: _mapGeofences(inactiveRows),
      vehicleCounts: _mapCounts(countRows),
    );
  }

  Future<void> createGeofence({
    required String name,
    required double centerLat,
    required double centerLon,
    required double radiusM,
    DateTime? effectiveFrom,
  }) async {
    final createdAt = _utcNow();
    final effective = effectiveFrom ?? createdAt;
    final geofenceId = _buildStableId(name, createdAt, 'gf');
    final geofenceVersionId = _buildStableId(name, createdAt, 'gfv');

    await _database.execute('BEGIN TRANSACTION');
    try {
      await _database.execute('''
        INSERT INTO geofences (geofence_id, created_at)
        VALUES (
          '${_escape(geofenceId)}',
          TIMESTAMP '${_escape(createdAt.toIso8601String())}'
        )
      ''');

      await _database.execute(_insertVersionSql(
        geofenceVersionId: geofenceVersionId,
        geofenceId: geofenceId,
        name: name,
        centerLat: centerLat,
        centerLon: centerLon,
        radiusM: radiusM,
        isActive: true,
        effectiveFrom: effective,
        createdAt: createdAt,
      ));

      await _database.execute('COMMIT');
    } catch (_) {
      await _database.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> editGeofence({
    required String geofenceId,
    required String name,
    required double centerLat,
    required double centerLon,
    required double radiusM,
    DateTime? effectiveFrom,
  }) async {
    final changedAt = _utcNow();
    final effective = effectiveFrom ?? changedAt;
    final geofenceVersionId = _buildStableId(name, changedAt, 'gfv');
    final latestVersion = await _requireLatestVersion(geofenceId);

    _ensureForwardOnly(
      geofenceId: geofenceId,
      effectiveFrom: effective,
      latestEffectiveFrom: latestVersion.effectiveFrom,
    );

    await _database.execute('BEGIN TRANSACTION');
    try {
      await _database.execute(_supersedeOpenVersionsSql(geofenceId, effective));
      await _database.execute(_insertVersionSql(
        geofenceVersionId: geofenceVersionId,
        geofenceId: geofenceId,
        name: name,
        centerLat: centerLat,
        centerLon: centerLon,
        radiusM: radiusM,
        isActive: true,
        effectiveFrom: effective,
        createdAt: changedAt,
      ));
      await _database.execute('COMMIT');
    } catch (_) {
      await _database.execute('ROLLBACK');
      rethrow;
    }
  }

  Future<void> deactivateGeofence({
    required String geofenceId,
    DateTime? effectiveFrom,
  }) async {
    final changedAt = _utcNow();
    final effective = effectiveFrom ?? changedAt;
    final geofenceVersionId = 'gfv_${_escape(geofenceId)}_inactive_${changedAt.microsecondsSinceEpoch}';
    final latestVersion = await _requireLatestVersion(geofenceId);

    _ensureForwardOnly(
      geofenceId: geofenceId,
      effectiveFrom: effective,
      latestEffectiveFrom: latestVersion.effectiveFrom,
    );

    await _database.execute('BEGIN TRANSACTION');
    try {
      await _database.execute(_supersedeOpenVersionsSql(geofenceId, effective));
      await _database.execute(_insertVersionSql(
        geofenceVersionId: geofenceVersionId,
        geofenceId: geofenceId,
        name: latestVersion.name,
        centerLat: latestVersion.centerLat,
        centerLon: latestVersion.centerLon,
        radiusM: latestVersion.radiusM,
        isActive: false,
        effectiveFrom: effective,
        createdAt: changedAt,
      ));
      await _database.execute('COMMIT');
    } catch (_) {
      await _database.execute('ROLLBACK');
      rethrow;
    }
  }

  String _activeGeofencesSql() {
    return '''
      WITH ranked_versions AS (
        SELECT
          gv.geofence_id,
          gv.geofence_version_id,
          gv.name,
          gv.center_lat,
          gv.center_lon,
          gv.radius_m,
          gv.is_active,
          gv.effective_from,
          g.created_at,
          ROW_NUMBER() OVER (
            PARTITION BY gv.geofence_id
            ORDER BY gv.effective_from DESC, g.created_at ASC
          ) AS rn
        FROM geofence_versions gv
        JOIN geofences g ON g.geofence_id = gv.geofence_id
      )
      SELECT
        geofence_id,
        geofence_version_id,
        name,
        center_lat,
        center_lon,
        radius_m,
        is_active,
        effective_from,
        created_at
      FROM ranked_versions
      WHERE rn = 1 AND is_active = TRUE
      ORDER BY name ASC
    ''';
  }

  String _inactiveGeofencesSql() {
    return '''
      WITH ranked_versions AS (
        SELECT
          gv.geofence_id,
          gv.geofence_version_id,
          gv.name,
          gv.center_lat,
          gv.center_lon,
          gv.radius_m,
          gv.is_active,
          gv.effective_from,
          g.created_at,
          ROW_NUMBER() OVER (
            PARTITION BY gv.geofence_id
            ORDER BY gv.effective_from DESC, g.created_at ASC
          ) AS rn
        FROM geofence_versions gv
        JOIN geofences g ON g.geofence_id = gv.geofence_id
      )
      SELECT
        geofence_id,
        geofence_version_id,
        name,
        center_lat,
        center_lon,
        radius_m,
        is_active,
        effective_from,
        created_at
      FROM ranked_versions
      WHERE rn = 1 AND is_active = FALSE
      ORDER BY effective_from DESC, name ASC
    ''';
  }

  String _vehicleCountsSql() {
    return '''
      WITH latest_versions AS (
        SELECT
          gv.geofence_id,
          gv.name,
          gv.is_active,
          ROW_NUMBER() OVER (
            PARTITION BY gv.geofence_id
            ORDER BY gv.effective_from DESC
          ) AS rn
        FROM geofence_versions gv
      ),
      current_geofences AS (
        SELECT geofence_id, name
        FROM latest_versions
        WHERE rn = 1 AND is_active = TRUE
      ),
      active_counts AS (
        SELECT
          cg.geofence_id,
          cg.name,
          COUNT(vgs.vehicle_id) AS vehicle_count,
          FALSE AS is_no_geofence
        FROM current_geofences cg
        LEFT JOIN vehicle_geofence_state vgs
          ON vgs.current_geofence_id = cg.geofence_id
        GROUP BY cg.geofence_id, cg.name
      ),
      no_geofence_count AS (
        SELECT
          NULL AS geofence_id,
          'No geofence' AS name,
          COUNT(*) AS vehicle_count,
          TRUE AS is_no_geofence
        FROM vehicles v
        LEFT JOIN vehicle_geofence_state vgs
          ON vgs.vehicle_id = v.vehicle_id
        WHERE vgs.current_geofence_id IS NULL
      )
      SELECT geofence_id, name, vehicle_count, is_no_geofence
      FROM active_counts
      UNION ALL
      SELECT geofence_id, name, vehicle_count, is_no_geofence
      FROM no_geofence_count
      ORDER BY is_no_geofence ASC, name ASC
    ''';
  }

  String _latestVersionSql(String geofenceId) {
    return '''
      SELECT name, center_lat, center_lon, radius_m, effective_from
      FROM geofence_versions
      WHERE geofence_id = '${_escape(geofenceId)}'
      ORDER BY effective_from DESC
      LIMIT 1
    ''';
  }

  Future<_LatestGeofenceVersion> _requireLatestVersion(String geofenceId) async {
    final latestRows = await _database.query(_latestVersionSql(geofenceId));
    if (latestRows.isEmpty) {
      throw StateError('Geofence not found: $geofenceId');
    }

    final latestRow = latestRows.first;
    return _LatestGeofenceVersion(
      name: latestRow[0] as String,
      centerLat: _asDouble(latestRow[1]),
      centerLon: _asDouble(latestRow[2]),
      radiusM: _asDouble(latestRow[3]),
      effectiveFrom: _asDateTime(latestRow[4]),
    );
  }

  void _ensureForwardOnly({
    required String geofenceId,
    required DateTime effectiveFrom,
    required DateTime latestEffectiveFrom,
  }) {
    if (effectiveFrom.isBefore(latestEffectiveFrom)) {
      throw StateError(
        'Geofence edits are forward-only: $geofenceId cannot move before '
        '${latestEffectiveFrom.toIso8601String()}.',
      );
    }
  }

  String _supersedeOpenVersionsSql(String geofenceId, DateTime effectiveFrom) {
    return '''
      UPDATE geofence_versions
      SET superseded_at = TIMESTAMP '${_escape(effectiveFrom.toIso8601String())}'
      WHERE geofence_id = '${_escape(geofenceId)}'
        AND superseded_at IS NULL
        AND effective_from < TIMESTAMP '${_escape(effectiveFrom.toIso8601String())}'
    ''';
  }

  String _insertVersionSql({
    required String geofenceVersionId,
    required String geofenceId,
    required String name,
    required double centerLat,
    required double centerLon,
    required double radiusM,
    required bool isActive,
    required DateTime effectiveFrom,
    required DateTime createdAt,
  }) {
    return '''
      INSERT INTO geofence_versions (
        geofence_version_id,
        geofence_id,
        name,
        center_lat,
        center_lon,
        radius_m,
        is_active,
        effective_from,
        superseded_at,
        created_at
      )
      VALUES (
        '${_escape(geofenceVersionId)}',
        '${_escape(geofenceId)}',
        '${_escape(name)}',
        $centerLat,
        $centerLon,
        $radiusM,
        ${isActive ? 'TRUE' : 'FALSE'},
        TIMESTAMP '${_escape(effectiveFrom.toIso8601String())}',
        NULL,
        TIMESTAMP '${_escape(createdAt.toIso8601String())}'
      )
    ''';
  }

  List<GeofenceListItem> _mapGeofences(List<List<Object?>> rows) {
    return rows.map((row) {
      return GeofenceListItem(
        geofenceId: row[0] as String,
        geofenceVersionId: row[1] as String,
        name: row[2] as String,
        centerLat: _asDouble(row[3]),
        centerLon: _asDouble(row[4]),
        radiusM: _asDouble(row[5]),
        isActive: _asBool(row[6]),
        effectiveFrom: _asDateTime(row[7]),
        createdAt: _asDateTime(row[8]),
      );
    }).toList(growable: false);
  }

  List<GeofenceVehicleCount> _mapCounts(List<List<Object?>> rows) {
    return rows.map((row) {
      return GeofenceVehicleCount(
        geofenceId: row[0] as String?,
        geofenceName: row[1] as String,
        vehicleCount: _asInt(row[2]),
        isNoGeofence: _asBool(row[3]),
      );
    }).toList(growable: false);
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is int) {
      return value != 0;
    }
    if (value is BigInt) {
      return value != BigInt.zero;
    }
    if (value is String) {
      return value.toUpperCase() == 'TRUE' || value == '1';
    }
    throw StateError('Unsupported boolean value: ${value.runtimeType}');
  }

  DateTime _asDateTime(Object? value) {
    if (value is DateTime) {
      return value.toUtc();
    }
    if (value is String) {
      return DateTime.parse(value).toUtc();
    }
    throw StateError('Unsupported datetime value: ${value.runtimeType}');
  }

  double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is BigInt) {
      return value.toDouble();
    }
    if (value is String) {
      return double.parse(value);
    }
    throw StateError('Unsupported numeric value: ${value.runtimeType}');
  }

  int _asInt(Object? value) {
    if (value == null) {
      return 0;
    }
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is BigInt) {
      return value.toInt();
    }
    if (value is String) {
      return int.parse(value);
    }
    throw StateError('Unsupported integer value: ${value.runtimeType}');
  }

  String _buildStableId(String name, DateTime timestamp, String prefix) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return '${prefix}_${slug.isEmpty ? 'geofence' : slug}_${timestamp.microsecondsSinceEpoch}';
  }

  String _escape(String input) => input.replaceAll("'", "''");
}

class _LatestGeofenceVersion {
  const _LatestGeofenceVersion({
    required this.name,
    required this.centerLat,
    required this.centerLon,
    required this.radiusM,
    required this.effectiveFrom,
  });

  final String name;
  final double centerLat;
  final double centerLon;
  final double radiusM;
  final DateTime effectiveFrom;
}
