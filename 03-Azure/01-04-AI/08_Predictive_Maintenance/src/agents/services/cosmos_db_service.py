"""Shared Cosmos DB access layer for Challenge 3 agents.

This module intentionally keeps things simple: it contains the shared data models
used by both agents and a single CosmosDbService that reads/writes the containers
used in the workshop.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import List, Optional

from azure.cosmos import CosmosClient, PartitionKey, exceptions

# =============================================================================
# Shared Models
# =============================================================================


@dataclass
class RequiredPart:
    """Part required for maintenance"""

    part_number: str = ""
    part_name: str = ""
    quantity: int = 0
    is_available: bool = False


@dataclass
class WorkOrder:
    """Work order from the Repair Planner Agent"""

    id: str = ""
    machine_id: str = ""
    fault_type: str = ""
    priority: str = ""
    assigned_technician: str = ""
    required_parts: List[RequiredPart] = field(default_factory=list)
    estimated_duration: int = 0
    created_at: Optional[datetime] = None
    status: str = "Created"


# =============================================================================
# Maintenance Models
# =============================================================================


@dataclass
class MaintenanceWindow:
    """Available maintenance window from MES"""

    id: str = ""
    start_time: Optional[datetime] = None
    end_time: Optional[datetime] = None
    production_impact: str = ""
    is_available: bool = True


@dataclass
class MaintenanceSchedule:
    """Predictive maintenance schedule output"""

    id: str = ""
    work_order_id: str = ""
    machine_id: str = ""
    scheduled_date: Optional[datetime] = None
    maintenance_window: Optional[MaintenanceWindow] = None
    risk_score: float = 0.0
    predicted_failure_probability: float = 0.0
    recommended_action: str = ""
    reasoning: str = ""
    created_at: Optional[datetime] = None


@dataclass
class MaintenanceHistory:
    """Historical maintenance record"""

    id: str = ""
    machine_id: str = ""
    fault_type: str = ""
    occurrence_date: Optional[datetime] = None
    resolution_date: Optional[datetime] = None
    downtime: int = 0
    cost: float = 0.0


# =============================================================================
# Parts Models
# =============================================================================


@dataclass
class InventoryItem:
    """Inventory item from WMS"""

    id: str = ""
    part_number: str = ""
    part_name: str = ""
    current_stock: int = 0
    min_stock: int = 0
    reorder_point: int = 0
    unit_cost: float = 0.0
    location: str = ""


@dataclass
class Supplier:
    """Supplier information from SCM"""

    id: str = ""
    name: str = ""
    parts: List[str] = field(default_factory=list)
    lead_time_days: int = 0
    reliability: str = ""
    contact_email: str = ""


@dataclass
class OrderItem:
    """Individual item in a parts order"""

    part_number: str = ""
    part_name: str = ""
    quantity: int = 0
    unit_cost: float = 0.0
    total_cost: float = 0.0


@dataclass
class PartsOrder:
    """Parts order for SCM system"""

    id: str = ""
    work_order_id: str = ""
    order_items: List[OrderItem] = field(default_factory=list)
    supplier_id: str = ""
    supplier_name: str = ""
    total_cost: float = 0.0
    expected_delivery_date: Optional[datetime] = None
    order_status: str = "Pending"
    created_at: Optional[datetime] = None


# =============================================================================
# Cosmos DB Service
# =============================================================================


class CosmosDbService:
    """Service for interacting with Cosmos DB."""

    def __init__(self, endpoint: str, key: str, database_name: str):
        self.client = CosmosClient(endpoint, key)
        self.database = self.client.get_database_client(database_name)

    def _parse_datetime(self, dt_value):
        """Parse datetime from ISO string."""
        if isinstance(dt_value, datetime):
            return dt_value
        if not dt_value:
            return None
        try:
            return datetime.fromisoformat(str(dt_value).replace("Z", "+00:00"))
        except Exception:
            return None

    def _ensure_container(self, container_id: str, partition_key_path: str):
        """Ensure a Cosmos container exists and return a usable container client.

        Note: get_container_client() does not validate existence; the NotFound shows
        up later when you try to read/write items.
        """

        container = self.database.get_container_client(container_id)
        try:
            container.read()  # force a service call to validate container exists
            return container
        except exceptions.CosmosResourceNotFoundError:
            self.database.create_container_if_not_exists(
                id=container_id,
                partition_key=PartitionKey(path=partition_key_path),
            )
            return self.database.get_container_client(container_id)

    # -------------------------------------------------------------------------
    # Work orders
    # -------------------------------------------------------------------------

    async def get_work_order(self, work_order_id: str) -> WorkOrder:
        """Get work order from ERP system."""

        container = self.database.get_container_client("WorkOrders")
        try:
            query = "SELECT * FROM c WHERE c.id = @id"
            items = list(
                container.query_items(
                    query=query,
                    parameters=[{"name": "@id", "value": work_order_id}],
                    enable_cross_partition_query=True,
                )
            )

            if not items:
                raise Exception(f"Work order {work_order_id} not found")

            item = items[0]
            return WorkOrder(
                id=item.get("id", ""),
                machine_id=item.get("machineId", ""),
                fault_type=item.get("faultType", ""),
                priority=item.get("priority", ""),
                assigned_technician=item.get("assignedTechnician", ""),
                required_parts=[
                    RequiredPart(
                        part_number=p.get("partNumber", ""),
                        part_name=p.get("partName", ""),
                        quantity=p.get("quantity", 0),
                        is_available=p.get("isAvailable", False),
                    )
                    for p in item.get("requiredParts", [])
                ],
                estimated_duration=item.get("estimatedDuration", 0),
                created_at=self._parse_datetime(item.get("createdAt")),
                status=item.get("status", "Created"),
            )
        except exceptions.CosmosHttpResponseError as e:
            raise Exception(f"Work order {work_order_id} not found: {str(e)}")

    async def update_work_order_status(self, work_order_id: str, status: str):
        """Update work order status."""

        container = self.database.get_container_client("WorkOrders")
        work_order = await self.get_work_order(work_order_id)
        old_status = work_order.status

        container.delete_item(item=work_order_id, partition_key=old_status)

        item = {
            "id": work_order.id,
            "machineId": work_order.machine_id,
            "faultType": work_order.fault_type,
            "priority": work_order.priority,
            "assignedTechnician": work_order.assigned_technician,
            "requiredParts": [
                {
                    "partNumber": p.part_number,
                    "partName": p.part_name,
                    "quantity": p.quantity,
                    "isAvailable": p.is_available,
                }
                for p in work_order.required_parts
            ],
            "estimatedDuration": work_order.estimated_duration,
            "createdAt": work_order.created_at.isoformat() if work_order.created_at else None,
            "status": status,
        }

        container.upsert_item(body=item)

    # -------------------------------------------------------------------------
    # Maintenance data
    # -------------------------------------------------------------------------

    async def get_maintenance_history(self, machine_id: str) -> List[MaintenanceHistory]:
        """Get historical maintenance records for a machine."""

        try:
            container = self.database.get_container_client(
                "MaintenanceHistory")
            query = (
                "SELECT * FROM c WHERE c.machineId = @machineId "
                "ORDER BY c.occurrenceDate DESC"
            )
            items = list(
                container.query_items(
                    query=query,
                    parameters=[{"name": "@machineId", "value": machine_id}],
                    enable_cross_partition_query=True,
                )
            )

            results: List[MaintenanceHistory] = []
            for item in items:
                results.append(
                    MaintenanceHistory(
                        id=item.get("id", ""),
                        machine_id=item.get("machineId", ""),
                        fault_type=item.get("faultType", ""),
                        occurrence_date=self._parse_datetime(
                            item.get("occurrenceDate")),
                        resolution_date=self._parse_datetime(
                            item.get("resolutionDate")),
                        downtime=item.get("downtime", 0),
                        cost=item.get("cost", 0.0),
                    )
                )

            return results
        except Exception as e:
            print(f"Warning: Could not retrieve maintenance history: {str(e)}")
            return []

    async def get_available_maintenance_windows(self, days_ahead: int = 14) -> List[MaintenanceWindow]:
        """Get available maintenance windows from MES."""

        try:
            container = self.database.get_container_client(
                "MaintenanceWindows")
            start_date = datetime.utcnow()
            end_date = start_date + timedelta(days=days_ahead)

            query = (
                "SELECT * FROM c "
                "WHERE c.startTime >= @startDate "
                "AND c.startTime <= @endDate "
                "AND c.isAvailable = true "
                "ORDER BY c.startTime"
            )

            items = list(
                container.query_items(
                    query=query,
                    parameters=[
                        {"name": "@startDate", "value": start_date.isoformat()},
                        {"name": "@endDate", "value": end_date.isoformat()},
                    ],
                    enable_cross_partition_query=True,
                )
            )

            results: List[MaintenanceWindow] = []
            for item in items:
                results.append(
                    MaintenanceWindow(
                        id=item.get("id", ""),
                        start_time=self._parse_datetime(item.get("startTime")),
                        end_time=self._parse_datetime(item.get("endTime")),
                        production_impact=item.get("productionImpact", ""),
                        is_available=item.get("isAvailable", True),
                    )
                )

            return results if results else self._generate_mock_windows(days_ahead)
        except Exception as e:
            print(f"Warning: Could not retrieve maintenance windows: {str(e)}")
            return self._generate_mock_windows(days_ahead)

    def _generate_mock_windows(self, days_ahead: int) -> List[MaintenanceWindow]:
        """Generate mock maintenance windows."""

        windows: List[MaintenanceWindow] = []
        start_date = (
            datetime.utcnow().replace(hour=0, minute=0, second=0, microsecond=0)
            + timedelta(days=1)
        )

        for i in range(days_ahead):
            current_date = start_date + timedelta(days=i)
            windows.append(
                MaintenanceWindow(
                    id=f"mw-{current_date.strftime('%Y-%m-%d')}-night",
                    start_time=current_date.replace(hour=22),
                    end_time=current_date.replace(hour=23, minute=59)
                    + timedelta(hours=6, minutes=1),
                    is_available=True,
                    production_impact="Low",
                )
            )

        return windows

    async def save_maintenance_schedule(self, schedule: MaintenanceSchedule) -> MaintenanceSchedule:
        """Save maintenance schedule to database."""

        container = self._ensure_container("MaintenanceSchedules", "/id")

        item = {
            "id": schedule.id,
            "workOrderId": schedule.work_order_id,
            "machineId": schedule.machine_id,
            "scheduledDate": schedule.scheduled_date.isoformat() if schedule.scheduled_date else None,
            "maintenanceWindow": {
                "id": schedule.maintenance_window.id,
                "startTime": schedule.maintenance_window.start_time.isoformat()
                if schedule.maintenance_window and schedule.maintenance_window.start_time
                else None,
                "endTime": schedule.maintenance_window.end_time.isoformat()
                if schedule.maintenance_window and schedule.maintenance_window.end_time
                else None,
                "productionImpact": schedule.maintenance_window.production_impact
                if schedule.maintenance_window
                else "",
                "isAvailable": schedule.maintenance_window.is_available
                if schedule.maintenance_window
                else True,
            }
            if schedule.maintenance_window
            else None,
            "riskScore": schedule.risk_score,
            "predictedFailureProbability": schedule.predicted_failure_probability,
            "recommendedAction": schedule.recommended_action,
            "reasoning": schedule.reasoning,
            "createdAt": schedule.created_at.isoformat() if schedule.created_at else None,
        }

        container.upsert_item(body=item)
        return schedule

    async def get_machine_chat_history(self, machine_id: str) -> Optional[str]:
        """Get chat history for a machine."""

        try:
            container = self.database.get_container_client("ChatHistories")
            item = container.read_item(
                item=machine_id, partition_key=machine_id)
            return item.get("historyJson")
        except exceptions.CosmosResourceNotFoundError:
            return None
        except Exception:
            return None

    async def save_machine_chat_history(self, machine_id: str, history_json: str):
        """Save chat history for a machine."""

        container = self._ensure_container("ChatHistories", "/entityId")

        item = {
            "id": machine_id,
            "entityId": machine_id,
            "entityType": "machine",
            "historyJson": history_json,
            "purpose": "predictive_maintenance",
            "updatedAt": datetime.utcnow().isoformat(),
        }

        container.upsert_item(body=item)

    # -------------------------------------------------------------------------
    # Inventory / suppliers
    # -------------------------------------------------------------------------

    async def get_inventory_items(self, part_numbers: List[str]) -> List[InventoryItem]:
        """Get inventory items from WMS."""

        try:
            container = self.database.get_container_client("PartsInventory")
            results: List[InventoryItem] = []

            for part_number in part_numbers:
                query = (
                    "SELECT * FROM c WHERE c.partNumber = @partNumber OR c.id = @partNumber"
                )
                items = list(
                    container.query_items(
                        query=query,
                        parameters=[
                            {"name": "@partNumber", "value": part_number}],
                        enable_cross_partition_query=True,
                    )
                )

                for item in items:
                    # Seeded documents use quantityInStock/reorderLevel/name/unitCost;
                    # keep the older key names as a fallback for compatibility.
                    results.append(
                        InventoryItem(
                            id=item.get("id", ""),
                            part_number=item.get("partNumber", ""),
                            part_name=item.get("name", item.get("partName", "")),
                            current_stock=item.get(
                                "quantityInStock", item.get("currentStock", 0)),
                            min_stock=item.get("minStock", 0),
                            reorder_point=item.get(
                                "reorderLevel", item.get("reorderPoint", 0)),
                            unit_cost=item.get("unitCost", 0.0),
                            location=item.get("location", ""),
                        )
                    )

            return results
        except Exception as e:
            print(f"Warning: Could not retrieve inventory: {str(e)}")
            return []

    async def get_suppliers_for_parts(self, part_numbers: List[str]) -> List[Supplier]:
        """Get suppliers from SCM that can provide specific parts."""

        try:
            container = self.database.get_container_client("Suppliers")
            items = list(container.query_items(
                query="SELECT * FROM c", enable_cross_partition_query=True))

            results: List[Supplier] = []
            for item in items:
                supplier_parts = item.get("partsSupplied", item.get("parts", []))
                if any(part in supplier_parts for part in part_numbers):
                    results.append(
                        Supplier(
                            id=item.get("id", ""),
                            name=item.get("name", ""),
                            parts=supplier_parts,
                            lead_time_days=item.get("leadTimeDays", 0),
                            reliability=item.get("reliability", ""),
                            contact_email=item.get("contactEmail", ""),
                        )
                    )

            return results if results else self._generate_mock_suppliers()
        except Exception as e:
            print(f"Warning: Could not retrieve suppliers: {str(e)}")
            return self._generate_mock_suppliers()

    def _generate_mock_suppliers(self) -> List[Supplier]:
        """Generate mock suppliers."""

        return [
            Supplier(
                id="supplier-001",
                name="Industrial Parts Supply Co.",
                parts=[],
                reliability="High",
                lead_time_days=3,
                contact_email="orders@industrialparts.com",
            ),
            Supplier(
                id="supplier-002",
                name="Quick Parts Ltd.",
                parts=[],
                reliability="Medium",
                lead_time_days=1,
                contact_email="sales@quickparts.com",
            ),
        ]

    async def save_parts_order(self, order: PartsOrder) -> PartsOrder:
        """Save parts order to SCM."""

        container = self._ensure_container("PartsOrders", "/id")

        item = {
            "id": order.id,
            "workOrderId": order.work_order_id,
            "orderItems": [
                {
                    "partNumber": oi.part_number,
                    "partName": oi.part_name,
                    "quantity": oi.quantity,
                    "unitCost": oi.unit_cost,
                    "totalCost": oi.total_cost,
                }
                for oi in order.order_items
            ],
            "supplierId": order.supplier_id,
            "supplierName": order.supplier_name,
            "totalCost": order.total_cost,
            "expectedDeliveryDate": order.expected_delivery_date.isoformat()
            if order.expected_delivery_date
            else None,
            "orderStatus": order.order_status,
            "createdAt": order.created_at.isoformat() if order.created_at else None,
        }

        container.upsert_item(body=item)
        return order

    async def get_work_order_chat_history(self, work_order_id: str) -> Optional[str]:
        """Get chat history for a work order."""

        try:
            container = self.database.get_container_client("ChatHistories")
            item = container.read_item(
                item=work_order_id, partition_key=work_order_id)
            return item.get("historyJson")
        except exceptions.CosmosResourceNotFoundError:
            return None
        except Exception:
            return None

    async def save_work_order_chat_history(self, work_order_id: str, history_json: str):
        """Save chat history for a work order."""

        container = self._ensure_container("ChatHistories", "/entityId")

        item = {
            "id": work_order_id,
            "entityId": work_order_id,
            "entityType": "workorder",
            "historyJson": history_json,
            "purpose": "parts_ordering",
            "updatedAt": datetime.utcnow().isoformat(),
        }

        container.upsert_item(body=item)
