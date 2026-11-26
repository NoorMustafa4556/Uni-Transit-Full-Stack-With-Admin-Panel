from rest_framework.response import Response
from rest_framework import status
from operations.models import ChangeRequest, AuditLog

def handle_maker_checker_mutation(request, entity_type, action, entity_id=None, serializer_class=None, instance=None):
    """
    Higher-Authority Maker-Checker rule:
    - Super Admin: performs live mutation directly + creates AuditLog.
    - Sub Admin: intercepts mutation, creates pending ChangeRequest, returns HTTP 202 Accepted.
    - Others: returns HTTP 403 Forbidden.
    """
    user = request.user
    if not (user and user.is_authenticated and not user.is_blocked):
        return Response({'detail': 'Authentication required.'}, status=status.HTTP_401_UNAUTHORIZED)

    if user.role == 'super_admin':
        if action == 'delete':
            target_str = str(instance)
            instance.delete()
            AuditLog.objects.create(
                actor=user,
                action=f"delete_{entity_type}",
                target=f"{entity_type} #{entity_id}: {target_str}",
                details="Directly deleted by Super Admin"
            )
            return Response({'message': f'{entity_type.capitalize()} deleted successfully.'}, status=status.HTTP_200_OK)

        is_partial = (action == 'patch')
        serializer = (
            serializer_class(instance, data=request.data, partial=is_partial)
            if instance else
            serializer_class(data=request.data)
        )
        if serializer.is_valid():
            saved_instance = serializer.save()
            AuditLog.objects.create(
                actor=user,
                action=f"{action}_{entity_type}",
                target=f"{entity_type} #{saved_instance.pk}: {str(saved_instance)}",
                details=str(serializer.validated_data)
            )
            http_status = status.HTTP_201_CREATED if action == 'create' else status.HTTP_200_OK
            return Response(serializer.data, status=http_status)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    elif user.role == 'sub_admin':
        payload = request.data if action != 'delete' else {'deleted_entity_id': entity_id}
        cr = ChangeRequest.objects.create(
            requested_by=user,
            entity_type=entity_type,
            entity_id=str(entity_id) if entity_id else None,
            action=action,
            payload_json=payload,
            status='pending',
        )
        AuditLog.objects.create(
            actor=user,
            action=f"request_{action}_{entity_type}",
            target=f"ChangeRequest #{cr.id} for {entity_type}",
            details=f"Sub-admin requested {action} on {entity_type} {entity_id or ''}"
        )
        return Response({
            'message': 'Change request submitted for Super Admin approval.',
            'change_request': {
                'id': cr.id,
                'entity_type': cr.entity_type,
                'entity_id': cr.entity_id,
                'action': cr.action,
                'payload_json': cr.payload_json,
                'status': cr.status,
                'created_at': cr.created_at,
            }
        }, status=status.HTTP_202_ACCEPTED)

    return Response({'detail': 'Admin privileges required.'}, status=status.HTTP_403_FORBIDDEN)
