-- Migration: Atomic Group Member Sequence Allocation
-- Created to fix P2 backlog item for concurrent group member registration

CREATE OR REPLACE FUNCTION increment_group_member_sequence(group_uuid uuid)
RETURNS int AS $$
DECLARE
    new_seq int;
BEGIN
    UPDATE groups
    SET current_member_sequence = COALESCE(current_member_sequence, 0) + 1
    WHERE group_id = group_uuid
    RETURNING current_member_sequence INTO new_seq;
    
    RETURN COALESCE(new_seq, 1);
END;
$$ LANGUAGE plpgsql;
