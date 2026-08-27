SELECT id, event_id, record_type_id, leader_id, registry_date, data_json, create_at, id_user_create_at, update_at, id_user_update_at, is_deleted, deleted_at, id_user_deleted_at
	FROM public.registry_events;

	SELECT id, name, description, target_organization_type_id, target_function_role_id, create_at, id_user_create_at, update_at, id_user_update_at, is_deleted, deleted_at, id_user_deleted_at
	FROM public.record_types;

	SELECT id, record_type_id, name, data_type, member_selection_logic, is_required, field_order, label, is_active, create_at, id_user_create_at, update_at, id_user_update_at, is_deleted, deleted_at, id_user_deleted_at
	FROM public.record_type_fields;

	SELECT id, event_id, record_type_id, create_at, id_user_create_at, update_at, id_user_update_at, is_deleted, deleted_at, id_user_deleted_at
	FROM public.event_record_types;

	SELECT id, name, date, description, is_in_person, is_recurring, recurring_days, organization_structure_id, create_at, id_user_create_at, update_at, id_user_update_at, is_deleted, deleted_at, id_user_deleted_at
	FROM public.events;