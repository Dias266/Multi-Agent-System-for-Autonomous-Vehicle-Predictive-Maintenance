// =============================================================================
// shared_beliefs.asl — Shared Ontology
// =============================================================================
// Included by ALL agents via maintenance.mas2j beliefs directive.
// Defines the common vocabulary (belief names, urgency levels, agent names)
// so all agents reason over the same terms.
//
// All three team members maintain this file jointly.
// =============================================================================

// ---------------------------------------------------------------------------
// Agent name constants (used in .send/broadcast targets)
// ---------------------------------------------------------------------------
agent_name(fleet_coordinator, fleet_coordinator_agent).
agent_name(service_center,    service_center_agent).
// VehicleAgents are addressed dynamically by their registered ID

// ---------------------------------------------------------------------------
// Urgency level ordering (low < medium < high < critical)
// Used by all agents for comparison in context conditions
// ---------------------------------------------------------------------------
urgency_order(low,      1).
urgency_order(medium,   2).
urgency_order(high,     3).
urgency_order(critical, 4).

// ---------------------------------------------------------------------------
// Booking pressure levels (mirrors fleet_coordinator_agent.asl)
// ---------------------------------------------------------------------------
pressure_level(low).
pressure_level(medium).
pressure_level(high).
pressure_level(critical).

// ---------------------------------------------------------------------------
// Component identifiers (canonical names from the IoT/ML layers)
// ---------------------------------------------------------------------------
component(engine).
component(brakes).
component(battery).
component(oil_pressure).
component(transmission).
component(tyre_pressure).

// ---------------------------------------------------------------------------
// Severity thresholds for urgency classification
// (ML health score → urgency: used by VehicleAgent)
// ---------------------------------------------------------------------------
urgency_threshold(critical, 0.90).   // score >= 0.90 → critical
urgency_threshold(high,     0.70).   // score >= 0.70 → high
urgency_threshold(medium,   0.40).   // score >= 0.40 → medium
// below 0.40 → low
