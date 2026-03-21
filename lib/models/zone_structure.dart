// MUNICIPAL ZONE & SUB-ZONE STRUCTURE
// Solapur Municipal Corporation - 8 Zones

class ZoneStructure {
  final String zoneId;
  final String zoneName;
  final List<SubZone> subZones;
  final String assistantEngineerId;
  final String deputyEngineerId;

  const ZoneStructure({
    required this.zoneId,
    required this.zoneName,
    required this.subZones,
    required this.assistantEngineerId,
    required this.deputyEngineerId,
  });
}

class SubZone {
  final String subZoneId;
  final String subZoneName;
  final String juniorEngineerId;
  final List<String> areas; // Area names covered

  const SubZone({
    required this.subZoneId,
    required this.subZoneName,
    required this.juniorEngineerId,
    required this.areas,
  });
}

// STATIC ZONE CONFIGURATION (Will be backend-driven in production)
class MunicipalZones {
  static const List<ZoneStructure> zones = [
    ZoneStructure(
      zoneId: 'Z1',
      zoneName: 'North Zone',
      assistantEngineerId: 'AE-Z1-001',
      deputyEngineerId: 'DE-Z1-001',
      subZones: [
        SubZone(
          subZoneId: 'Z1-SZ1',
          subZoneName: 'North Central',
          juniorEngineerId: 'JE-Z1-SZ1-001',
          areas: ['Sadar Bazaar', 'Murarji Peth', 'Budhwar Peth'],
        ),
        SubZone(
          subZoneId: 'Z1-SZ2',
          subZoneName: 'North East',
          juniorEngineerId: 'JE-Z1-SZ2-001',
          areas: ['Ashok Chowk', 'Vijapur Road', 'Hotgi Road'],
        ),
        SubZone(
          subZoneId: 'Z1-SZ3',
          subZoneName: 'North West',
          juniorEngineerId: 'JE-Z1-SZ3-001',
          areas: ['Sidheshwar Peth', 'Railway Lines', 'Shukrawar Peth'],
        ),
      ],
    ),
    ZoneStructure(
      zoneId: 'Z2',
      zoneName: 'South Zone',
      assistantEngineerId: 'AE-Z2-001',
      deputyEngineerId: 'DE-Z2-001',
      subZones: [
        SubZone(
          subZoneId: 'Z2-SZ1',
          subZoneName: 'South Central',
          juniorEngineerId: 'JE-Z2-SZ1-001',
          areas: ['Jule Solapur', 'Sakhar Peth', 'Akkalkot Road'],
        ),
        SubZone(
          subZoneId: 'Z2-SZ2',
          subZoneName: 'South West',
          juniorEngineerId: 'JE-Z2-SZ2-001',
          areas: ['Mangalwar Peth', 'Shelgi', 'Bhavani Peth'],
        ),
      ],
    ),
    ZoneStructure(
      zoneId: 'Z3',
      zoneName: 'East Zone',
      assistantEngineerId: 'AE-Z3-001',
      deputyEngineerId: 'DE-Z3-001',
      subZones: [
        SubZone(
          subZoneId: 'Z3-SZ1',
          subZoneName: 'East Central',
          juniorEngineerId: 'JE-Z3-SZ1-001',
          areas: ['Navi Peth', 'Kambar Talav', 'Modak Ali'],
        ),
        SubZone(
          subZoneId: 'Z3-SZ2',
          subZoneName: 'East Industrial',
          juniorEngineerId: 'JE-Z3-SZ2-001',
          areas: ['MIDC', 'Pandharpur Road', 'Golani Market'],
        ),
      ],
    ),
    ZoneStructure(
      zoneId: 'Z4',
      zoneName: 'West Zone',
      assistantEngineerId: 'AE-Z4-001',
      deputyEngineerId: 'DE-Z4-001',
      subZones: [
        SubZone(
          subZoneId: 'Z4-SZ1',
          subZoneName: 'West Central',
          juniorEngineerId: 'JE-Z4-SZ1-001',
          areas: ['Kegaon', 'Kasegaon Road', 'Islampur'],
        ),
        SubZone(
          subZoneId: 'Z4-SZ2',
          subZoneName: 'West Outer',
          juniorEngineerId: 'JE-Z4-SZ2-001',
          areas: ['Bale', 'Sangola Road', 'Vairag'],
        ),
      ],
    ),
    ZoneStructure(
      zoneId: 'Z5',
      zoneName: 'Central Zone',
      assistantEngineerId: 'AE-Z5-001',
      deputyEngineerId: 'DE-Z5-001',
      subZones: [
        SubZone(
          subZoneId: 'Z5-SZ1',
          subZoneName: 'CBD Area',
          juniorEngineerId: 'JE-Z5-SZ1-001',
          areas: ['Mahavir Chowk', 'Station Road', 'Raviwar Peth'],
        ),
        SubZone(
          subZoneId: 'Z5-SZ2',
          subZoneName: 'Central Market',
          juniorEngineerId: 'JE-Z5-SZ2-001',
          areas: ['Sambhaji Chowk', 'Gandhi Chowk', 'Nehru Chowk'],
        ),
      ],
    ),
    ZoneStructure(
      zoneId: 'Z6',
      zoneName: 'Industrial Zone',
      assistantEngineerId: 'AE-Z6-001',
      deputyEngineerId: 'DE-Z6-001',
      subZones: [
        SubZone(
          subZoneId: 'Z6-SZ1',
          subZoneName: 'Heavy Industrial',
          juniorEngineerId: 'JE-Z6-SZ1-001',
          areas: ['MIDC Phase 1', 'Industrial Estate', 'Factory Area'],
        ),
        SubZone(
          subZoneId: 'Z6-SZ2',
          subZoneName: 'Logistics Hub',
          juniorEngineerId: 'JE-Z6-SZ2-001',
          areas: ['Transport Nagar', 'Warehousing Zone', 'Truck Terminal'],
        ),
      ],
    ),
    ZoneStructure(
      zoneId: 'Z7',
      zoneName: 'Residential Zone',
      assistantEngineerId: 'AE-Z7-001',
      deputyEngineerId: 'DE-Z7-001',
      subZones: [
        SubZone(
          subZoneId: 'Z7-SZ1',
          subZoneName: 'Housing Colonies',
          juniorEngineerId: 'JE-Z7-SZ1-001',
          areas: ['PWD Colony', 'Railway Colony', 'Police Lines'],
        ),
        SubZone(
          subZoneId: 'Z7-SZ2',
          subZoneName: 'Apartment Clusters',
          juniorEngineerId: 'JE-Z7-SZ2-001',
          areas: ['Jyoti Nagar', 'Indira Nagar', 'Shivaji Nagar'],
        ),
      ],
    ),
    ZoneStructure(
      zoneId: 'Z8',
      zoneName: 'Peripheral Zone',
      assistantEngineerId: 'AE-Z8-001',
      deputyEngineerId: 'DE-Z8-001',
      subZones: [
        SubZone(
          subZoneId: 'Z8-SZ1',
          subZoneName: 'Outer Ring',
          juniorEngineerId: 'JE-Z8-SZ1-001',
          areas: ['Barshi Road', 'Pune Road', 'Tuljapur Road'],
        ),
        SubZone(
          subZoneId: 'Z8-SZ2',
          subZoneName: 'Rural Fringe',
          juniorEngineerId: 'JE-Z8-SZ2-001',
          areas: ['Village Clusters', 'Outskirts', 'Highway Sections'],
        ),
      ],
    ),
  ];

  // Geographic assignment: Find zone/sub-zone by area name
  static Map<String, dynamic>? getZoneByArea(String area) {
    for (var zone in zones) {
      for (var subZone in zone.subZones) {
        if (subZone.areas.any(
          (a) => a.toLowerCase().contains(area.toLowerCase()),
        )) {
          return {
            'zone': zone,
            'subZone': subZone,
            'juniorEngineerId': subZone.juniorEngineerId,
            'assistantEngineerId': zone.assistantEngineerId,
            'deputyEngineerId': zone.deputyEngineerId,
          };
        }
      }
    }
    return null;
  }

  // Get all areas for a Junior Engineer
  static List<String> getAreasForJE(String jeId) {
    for (var zone in zones) {
      for (var subZone in zone.subZones) {
        if (subZone.juniorEngineerId == jeId) {
          return subZone.areas;
        }
      }
    }
    return [];
  }

  // Get all sub-zones for an Assistant Engineer
  static List<SubZone> getSubZonesForAE(String aeId) {
    for (var zone in zones) {
      if (zone.assistantEngineerId == aeId) {
        return zone.subZones;
      }
    }
    return [];
  }

  // Get all sub-zones for a Deputy Engineer
  static List<SubZone> getSubZonesForDE(String deId) {
    for (var zone in zones) {
      if (zone.deputyEngineerId == deId) {
        return zone.subZones;
      }
    }
    return [];
  }

  // Get zone name for a JE
  static String? getZoneNameForJE(String jeId) {
    for (var zone in zones) {
      for (var subZone in zone.subZones) {
        if (subZone.juniorEngineerId == jeId) {
          return zone.zoneName;
        }
      }
    }
    return null;
  }
}
