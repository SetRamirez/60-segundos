using Godot;
using System.Linq;
using System.Threading.Tasks;

public partial class Dado : RigidBody3D
{
    /// <summary>Velocidad (lineal y angular) por debajo de la cual el dado se considera quieto.</summary>
    [Export] public float UmbralQuieto { get; set; } = 0.1f;
    /// <summary>Segundos seguidos que tiene que estar quieto para leer el resultado.</summary>
    [Export] public float TiempoQuieto { get; set; } = 0.4f;
    /// <summary>Si pasado este tiempo el dado sigue moviéndose (vibra, se cayó de la mesa...), se vuelve a tirar.</summary>
    [Export] public float TiempoMaximo { get; set; } = 8.0f;
    /// <summary>Qué tan hacia abajo debe apuntar la cara apoyada (1 = perfectamente plana) para aceptar el resultado.</summary>
    [Export] public float AlineacionMinima { get; set; } = 0.9f;
    /// <summary>Impulso con el que se lanza el dado (la mitad se usa como giro).</summary>
    [Export] public float FuerzaTiro { get; set; } = 30.0f;

    [Signal]
    public delegate void TiroFinalizadoEventHandler(int valor);

    private RaycastDado[] _raycasts;
    private Vector3 _posInicial; // local, igual que Transform.Origin, que es donde se restaura
    private bool _lanzando = false; // evita emitir un resultado cuando el dado se queda quieto sin haber sido tirado
    private double _segundosQuieto = 0.0;
    private double _segundosLanzado = 0.0;

    public override void _Ready()
    {
        _raycasts = GetNode("Raycasts").GetChildren().Cast<RaycastDado>().ToArray();
        _posInicial = Position;
    }

    /// <summary>
    /// Tira el dado y espera a que se detenga: devuelve el valor de la cara de arriba.
    /// Se usa con await: int valor = await dado.Lanzar();
    /// </summary>
    public async Task<int> Lanzar()
    {
        EmpezarTiro();
        // ToSignal espera a que se emita la señal; sus argumentos llegan en un array de Variant.
        Variant[] argumentos = await ToSignal(this, SignalName.TiroFinalizado);
        return argumentos[0].AsInt32();
    }

    // También se usa para repetir la tirada cuando el dado queda inclinado o no se detiene.
    private void EmpezarTiro()
    {
        _lanzando = true;
        _segundosQuieto = 0.0;
        _segundosLanzado = 0.0;
        Sleeping = false;
        Freeze = false;
        LinearVelocity = Vector3.Zero;
        AngularVelocity = Vector3.Zero;

        // Transform es un struct: se copia, se modifica la copia y se vuelve a asignar.
        Transform3D t = Transform;
        t.Origin = _posInicial;
        t.Basis = new Basis(Vector3.Right, AnguloAleatorio()) * t.Basis;
        t.Basis = new Basis(Vector3.Up, AnguloAleatorio()) * t.Basis;
        t.Basis = new Basis(Vector3.Forward, AnguloAleatorio()) * t.Basis;
        Transform = t;

        var throwVector = new Vector3((float)GD.RandRange(-1.0, 1.0), 0, (float)GD.RandRange(-1.0, 1.0)).Normalized();
        AngularVelocity = throwVector * FuerzaTiro / 2;
        ApplyCentralImpulse(throwVector * FuerzaTiro);
    }

    private static float AnguloAleatorio()
    {
        return (float)GD.RandRange(0.0, Mathf.Tau);
    }

    public override void _PhysicsProcess(double delta)
    {
        if (!_lanzando)
            return;
        _segundosLanzado += delta;
        if (LinearVelocity.Length() < UmbralQuieto && AngularVelocity.Length() < UmbralQuieto)
        {
            _segundosQuieto += delta;
            if (_segundosQuieto >= TiempoQuieto)
                LeerResultado();
        }
        else
        {
            _segundosQuieto = 0.0;
            if (_segundosLanzado > TiempoMaximo)
                EmpezarTiro();
        }
    }

    // La cara apoyada en la mesa es la del raycast que apunta más hacia abajo.
    private void LeerResultado()
    {
        RaycastDado caraAbajo = null;
        float mejorAlineacion = -1.0f;
        foreach (RaycastDado raycast in _raycasts)
        {
            Vector3 direccion = (raycast.GlobalBasis * raycast.TargetPosition).Normalized();
            float alineacion = direccion.Dot(Vector3.Down);
            if (alineacion > mejorAlineacion)
            {
                mejorAlineacion = alineacion;
                caraAbajo = raycast;
            }
        }
        if (mejorAlineacion < AlineacionMinima)
        {
            EmpezarTiro(); // quedó inclinado (apoyado en una pared o en una arista): se repite
            return;
        }
        _lanzando = false;
        EmitSignal(SignalName.TiroFinalizado, caraAbajo.OppositeSide);
    }
}
