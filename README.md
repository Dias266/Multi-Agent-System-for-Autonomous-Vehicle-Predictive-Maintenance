# Vehicle MAS Maintenance — Fleet Coordinator Setup

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Java JDK | 11+ | Required for env/ compilation |
| Jason | 3.x | Download jar manually (see below) |
| Gradle | 7+ | Or use `gradlew` wrapper |

---

## 1. Download Jason

Jason does not publish to Maven Central. Download the jar manually:

1. Go to: https://sourceforge.net/projects/jason/files/jason/
2. Download `jason-3.x.jar` (latest 3.x release)
3. Place it in `lib/jason-3.x.jar`

```
vehicle-mas-maintenance/
└── lib/
    └── jason-3.2.jar   ← place here
```

---

## 2. Project Structure

```
vehicle-mas-maintenance/
│
├── mas/
│   ├── maintenance.mas2j               ← MAS entry point (run this)
│   ├── agents/
│   │   ├── fleet_coordinator_agent.asl ← Dias (this file)
│   │   ├── vehicle_agent.asl           ← Danial (stub until integration)
│   │   └── service_center_agent.asl    ← Mary  (stub until integration)
│   └── common/
│       └── shared_beliefs.asl          ← Shared ontology (all 3 maintain)
│
├── env/
│   └── FleetMASEnvironment.java        ← Java bridge (IoT + ML + Blockchain)
│
├── data/
│   └── scenarios/
│       ├── scenario_normal.json
│       ├── scenario_high_urgency.json
│       └── scenario_parts_shortage.json
│
├── lib/
│   └── jason-3.x.jar                   ← place Jason jar here
│
├── build.gradle
└── README.md
```

---

## 3. Compile

```bash
gradle compileJava
```

This compiles `env/FleetMASEnvironment.java` into `build/classes/`.

---

## 4. Run the MAS

### Option A — Gradle (recommended)

```bash
gradle run
```

### Option B — Jason CLI directly

```bash
java -cp "lib/jason-3.x.jar:build/classes/java/main" \
     jason.infra.centralised.RunCentralisedMAS \
     mas/maintenance.mas2j
```

### Option C — jEdit + Jason plugin (GUI with step debugger)

1. Open jEdit with the Jason plugin installed
2. File → Open → `mas/maintenance.mas2j`
3. Click the **Run** button (or Plugins → Jason → Run MAS)
4. Agent reasoning traces appear in the Jason console panel

---

## 5. Expected Output

```
[FleetCoordinator] Booting up — stigmergy coordination active.
[FleetCoordinator] Registered with MaintenanceDataBridge.
[FleetCoordinator] Broadcasting booking_pressure: low
[FleetCoordinator] Monitoring IoT stream for fleet-wide anomaly patterns.
[VehicleAgent:vehicle_agent1] Starting up (stub).
[VehicleAgent:vehicle_agent2] Starting up (stub).
[VehicleAgent:vehicle_agent3] Starting up (stub).
[ServiceCenterAgent] Online (stub) — awaiting requests.
[FleetCoordinator] Anomaly from vehicle_agent1 type=brake_wear severity=high
[FleetCoordinator] Anomaly from vehicle_agent2 type=brake_wear severity=medium
[FleetCoordinator] COLLECTIVE ALERT — anomaly pattern detected: brake_wear across 2 vehicles.
[FleetCoordinator] Broadcast sent: fleet_anomaly_alert(brake_wear,2).
[BLOCKCHAIN-MOCK] Fleet anomaly logged: brake_wear x2
```

---

## 6. Swapping Mocks for Real Integrations

In `FleetMASEnvironment.java`, replace the mock constructors in `init()`:

```java
// Current (mock):
iotAdapter        = new MockIoTStream();
mlAdapter         = new MockMLPipeline();
blockchainAdapter = new MockBlockchainClient();

// Replace with real adapters:
iotAdapter        = new MQTTIoTStream("mqtt://localhost:1883");
mlAdapter         = new HTTPMLPipeline("http://localhost:5000/predict");
blockchainAdapter = new FabricBlockchainClient("connection-profile.yaml");
```

Each real adapter must implement the corresponding interface:
- `IoTStreamAdapter`
- `MLPipelineAdapter`
- `BlockchainAdapter`

---

## 7. Running Specific Scenarios

Edit `MockIoTStream` in `FleetMASEnvironment.java` to load from a scenario file,
or pass the scenario path as an init arg in `maintenance.mas2j`:

```
environment: env.FleetMASEnvironment("data/scenarios/scenario_high_urgency.json")
```

Then update `FleetMASEnvironment.init(String[] args)` to read `args[0]`.

---

## Team

| Agent | Owner | File |
|-------|-------|------|
| FleetCoordinatorAgent | Dias | `fleet_coordinator_agent.asl` |
| VehicleAgent | Danial | `vehicle_agent.asl` |
| ServiceCenterAgent | Mary | `service_center_agent.asl` |
| Java environment bridge | All | `FleetMASEnvironment.java` |
