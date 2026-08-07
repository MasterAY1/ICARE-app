from database.repositories.unit_of_work import SupabaseUnitOfWork

with SupabaseUnitOfWork() as uow:
    # 1. Fetch all clients
    res = uow.client.table('clients').select('client_id, name, client_code, branch_id').execute()
    
    # Filter in python
    mig_clients = [c for c in res.data if c.get('client_code') and c['client_code'].startswith('OGI-MIG-')]
    
    for c in mig_clients:
        c_id = c['client_id']
        branch_id = c['branch_id']
        
        # Determine group
        m_res = uow.client.table('client_memberships').select('group_id').eq('client_id', c_id).execute()
        
        g_id = None
        g_num = None
        seq = None
        if m_res.data:
            g_id = m_res.data[0]['group_id']
            # Fetch group info separately
            g_res = uow.client.table('groups').select('group_number, current_member_sequence').eq('group_id', g_id).execute()
            if g_res.data:
                g_num = g_res.data[0]['group_number']
                seq = g_res.data[0]['current_member_sequence'] or 0
                
        if g_num:
            # We found a group!
            new_seq = seq + 1
            new_code = f'OGI-{g_num}-{str(new_seq).zfill(3)}'
            
            # Update client
            uow.client.table('clients').update({'client_code': new_code}).eq('client_id', c_id).execute()
            
            # Update group sequence
            uow.client.table('groups').update({'current_member_sequence': new_seq}).eq('group_id', g_id).execute()
            print(f"Updated {c['name']} to {new_code}")
        else:
            print(f"No group found for {c['name']}")
