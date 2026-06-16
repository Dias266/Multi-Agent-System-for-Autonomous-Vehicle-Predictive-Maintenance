// =============================================================================
// service_center_agent.asl — ServiceCenterAgent
// =============================================================================
// Owner: Mary
// ISE Project: Multi-Agent System for Autonomous Vehicle Predictive Maintenance
// 
// Responsibilities:
// 1. Resource Management - technician capacity, parts inventory, slot calendar
// 2. Request Handling - accept / defer / decline booking requests
// 3. Service Execution - log immutable service record, publish competition
// 4. Consensus Participation - multi-org endorsment of service records
//
// Shared Protocol:
// Coordinator > Service: booking_request(Vehicle, Part, Urgency)
// Service > Vehicle: booking_confirmed(Slot, Center)
//                    booking_deferred(AltSlot, Center)
//                    booking_declined(Reason)
//Service > Coordinator: booking_confirmed(Vehicle) (decays pressure)
//                       endorse_request(RecordID, Vehicle) (cross-org sign)
//Coordinator > Service: endorsement (RecordID, approve/reject)
// =============================================================================

// ---------------------------------------------------------------------------
// INITIAL BELIEFS - resource model
// ---------------------------------------------------------------------------

// Technician capacity (free techhnician-slots right now)
current_capacity(3).

// Service-slot Calendar
available_slot(slot1, available).
available_slot(slot2, available).
available_slot(slot3, available).

//Parts inventory (per-part stock levels)
parts_inventory(brake_pad, 10).
parts_inventory(oil_filter, 10).

//Pricing (used when logging the service record)
parts_cost(brake_pad, 80).
parts_cost(oil_filter, 25).
service_cost(labour_hour, 60).

//Technicians and their qualifications
technician(tech_a).
technician(tech_b).
qualified(tech_a, brake_pad).
qualified(tech_a, oil_filter).
qualified(tech_b, oil_filter).

//Bookkeeping
record_counter(0).        //monotic service-record id(preserves ordering)
is_overloaded(false).

// State
is_overloaded(false).

// ---------------------------------------------------------------------------
// RULES
// ---------------------------------------------------------------------------

// A record is valid for endorsment if we hold it in our local ledger view. record_valid(RID):- service_record(RID, _, _, _, _).

// ---------------------------------------------------------------------------
// INITIAL GOALS
// ---------------------------------------------------------------------------

!start.

// ---------------------------------------------------------------------------
// PLANS: STARTUP
// ---------------------------------------------------------------------------

+!start
    <- .print("[ServiceCenterAgent] Operational. Ready for maintenance requests.").
       !advertise_capacity.

// Publish current free capacity to the fleet (stigmergy / MQTT analog)
+!advertise_capacity
    :  current_capacity(C)
    <- .send(fleet_coordinator_agent, tell, service_center_capacity(C));
       .print("[ServiceCenterAgent] Advertising free capacity: ", C).

// ---------------------------------------------------------------------------
// PLANS: HANDLING REQUESTS
// ---------------------------------------------------------------------------

// Booking request forwarded by the FleetCoordinator. Carries the required Part.
+booking_request(VehicleID, Part, Urgency)
    <- .print("[ServiceCenterAgent] Received request from ", VehicleID,
              " (part=", Part, ", urgency=", Urgency, ")");
       !evaluate_request(VehicleID, Part, Urgency).
 
// 1. Success: free slot AND part in stock AND capacity AND a qualified technician
+!evaluate_request(VehicleID, Part, Urgency)
    :  available_slot(SlotID, available)
     & parts_inventory(Part, Qty) & Qty > 0
     & current_capacity(C) & C > 0
     & qualified(Tech, Part)
    <- .print("[ServiceCenterAgent] Resources found. Allocating ", SlotID,
              " to ", VehicleID, " (tech=", Tech, ")");
       !perform_booking(VehicleID, SlotID, Part, Tech).
 
// 2. Parts shortage: requested part out of stock -> decline with reason
+!evaluate_request(VehicleID, Part, Urgency)
    :  parts_inventory(Part, 0)
    <- .print("[ServiceCenterAgent] DECLINED: out of stock for ", Part);
       .send(VehicleID, tell, booking_declined(parts_shortage(Part))).
 
// 3. No qualified technician for this part -> decline with reason
+!evaluate_request(VehicleID, Part, Urgency)
    :  not qualified(_, Part)
    <- .print("[ServiceCenterAgent] DECLINED: no qualified technician for ", Part);
       .send(VehicleID, tell, booking_declined(no_qualified_technician(Part))).
 
// 4. Capacity exhausted -> counter-offer the next available slot (defer)
+!evaluate_request(VehicleID, Part, Urgency)
    :  current_capacity(C) & C <= 0
    <- .print("[ServiceCenterAgent] FULL (no free technicians) — deferring ", VehicleID);
       .send(VehicleID, tell, booking_deferred(next_available, service_center_agent)).
 
// 5. No free slots -> counter-offer the next available slot (defer)
+!evaluate_request(VehicleID, Part, Urgency)
    :  not available_slot(_, available)
    <- .print("[ServiceCenterAgent] FULL (no free slots) — deferring ", VehicleID);
       .send(VehicleID, tell, booking_deferred(next_available, service_center_agent)).
 
// 6. Fallback: anything else we cannot serve right now
+!evaluate_request(VehicleID, Part, Urgency)
    <- .print("[ServiceCenterAgent] Unable to serve ", VehicleID, " at this time.");
       .send(VehicleID, tell, booking_declined(unavailable)).

// ---------------------------------------------------------------------------
// PLANS: BOOKING, RESOURCE UPDATES & SERVICE EXECUTION
// ---------------------------------------------------------------------------
+!perform_booking(VehicleID, SlotID, Part, Tech)
    <- // Reserve the slot and one technician
       -+available_slot(SlotID, occupied);
       ?current_capacity(C); NewCap = C - 1; -+current_capacity(NewCap);
 
       // Reserve one unit of the required part
       ?parts_inventory(Part, Qty); NewQty = Qty - 1;
       -parts_inventory(Part, Qty); +parts_inventory(Part, NewQty);
 
       // Compute the service cost (parts + one labour hour)
       ?parts_cost(Part, PC); ?service_cost(labour_hour, LC); Cost = PC + LC;
 
       // Create an immutable, monotonically-ordered service record
       ?record_counter(RC); RID = RC + 1; -+record_counter(RID);
       +service_record(RID, VehicleID, Part, Tech, Cost);
 
       // Log the record to the blockchain (Codice 87474)
       writeServiceRecord(VehicleID, scheduled_maintenance);
       .print("[ServiceCenterAgent] Logged record #", RID, " — vehicle=", VehicleID,
              " part=", Part, " tech=", Tech, " cost=", Cost);
 
       // Request multi-organisation endorsement from the FleetCoordinator
       .send(fleet_coordinator_agent, tell, endorse_request(RID, VehicleID));
 
       // Confirm the booking to the vehicle and notify the coordinator
       .send(VehicleID, tell, booking_confirmed(SlotID, service_center_agent));
       .send(fleet_coordinator_agent, tell, booking_confirmed(VehicleID));
 
       // Publish service completion (stigmergy / MQTT analog)
       !complete_service(VehicleID, Part, Tech, RID);
 
       .wait(2000);
       !release_slot(SlotID).
 
+!complete_service(VehicleID, Part, Tech, RID)
    <- .send(fleet_coordinator_agent, tell, service_completed(VehicleID, RID));
       .print("[ServiceCenterAgent] Service completed for ", VehicleID,
              " by ", Tech, " (record #", RID, ").").
 
+!release_slot(SlotID)
    <- -+available_slot(SlotID, available);
       ?current_capacity(C); FreedCap = C + 1; -+current_capacity(FreedCap);
       .print("[ServiceCenterAgent] ", SlotID, " is now free — capacity restored to ", FreedCap);
       !advertise_capacity.

// ---------------------------------------------------------------------------
// PLANS: CONSENSUS PARTICIPATION (endorsement)
// ---------------------------------------------------------------------------
 
// Endorsement reply for one of OUR records (from the FleetCoordinator's org)
+endorsement(RID, approve)
    <- .print("[ServiceCenterAgent] Record #", RID,
              " ENDORSED (approve) — committed to ledger.").
 
+endorsement(RID, reject)
    <- .print("[ServiceCenterAgent] Record #", RID,
              " endorsement REJECTED — placing integrity hold.");
       -service_record(RID, _, _, _, _).
 
// Validate a service record proposed by another peer (Byzantine validation)
+endorse_request(RID, Originator)[source(Peer)]
    :  record_valid(RID)
    <- .print("[ServiceCenterAgent] Peer record #", RID, " from ", Originator, " — APPROVE.");
       .send(Peer, tell, endorsement(RID, approve)).
 
+endorse_request(RID, Originator)[source(Peer)]
    :  not record_valid(RID)
    <- .print("[ServiceCenterAgent] Peer record #", RID, " from ", Originator,
              " — REJECT (unknown record).");
       .send(Peer, tell, endorsement(RID, reject)).

// ---------------------------------------------------------------------------
// PLANS: COORDINATION & OVERLOAD
// ---------------------------------------------------------------------------

// Reacting to the FleetCoordinator's overload warning
+fleet_overload_warning(Level)
    <- -+is_overloaded(true);
       .print("[ServiceCenterAgent] High fleet pressure alert: ", Level, ". Prioritising urgent jobs.").

+fleet_status(Size, Pressure)
    <- .print("[ServiceCenterAgent] Fleet Status Report — Vehicles: ", Size, " System Pressure: ", Pressure).

// ---------------------------------------------------------------------------
// PLANS: FAILURE FALLBACK
// ---------------------------------------------------------------------------

-!X
    <- .print("[ServiceCenterAgent] Plan failed: ", X).
