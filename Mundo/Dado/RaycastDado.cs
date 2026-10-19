using Godot;

/// <summary>
/// Raycast de una cara del dado. Si apunta hacia abajo, la cara de arriba es OppositeSide.
/// </summary>
public partial class RaycastDado : RayCast3D
{
    [Export] public int OppositeSide { get; set; }

    public override void _Ready()
    {
        // El dueño es el propio dado (dado.tscn): el raycast no debe chocar con él.
        AddException((CollisionObject3D)Owner);
    }
}
