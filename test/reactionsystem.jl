using ModelingToolkit, LinearAlgebra, Test

@parameters t k[1:20]
@variables A(t) B(t) C(t) D(t)
rxs = [Reaction(k[1], nothing, [A]),            # 0 -> A
       Reaction(k[2], [B], nothing),            # B -> 0
       Reaction(k[3],[A],[C]),                  # A -> C
       Reaction(k[4], [C], [A,B]),              # C -> A + B
       Reaction(k[5], [C], [A], [1], [2]),      # C -> A + A
       Reaction(k[6], [A,B], [C]),              # A + B -> C
       Reaction(k[7], [B], [A], [2], [1]),      # 2B -> A
       Reaction(k[8], [A,B], [A,C]),            # A + B -> A + C
       Reaction(k[9], [A,B], [C,D]),            # A + B -> C + D
       Reaction(k[10], [A], [C,D], [2], [1,1]), # 2A -> C + D
       Reaction(k[11], [A], [A,B], [2], [1,1]), # 2A -> A + B
       Reaction(k[12], [A,B,C], [C,D], [1,3,4], [2, 3]),          # A+3B+4C -> 2C + 3D
       Reaction(k[13], [A,B], nothing, [3,1], nothing),           # 3A+B -> 0
       Reaction(k[14], nothing, [A], nothing, [2]),               # 0 -> 2A
       Reaction(k[15]*A/(2+A), [A], nothing; only_use_rate=true), # A -> 0 with custom rate
       Reaction(k[16], [A], [B]; only_use_rate=true),             # A -> B with custom rate.
       Reaction(k[17]*A*exp(B), [C], [D], [2], [1]),              # 2C -> D with non constant rate.
       Reaction(k[18]*B, nothing, [B], nothing, [2]),             # 0 -> 2B with non constant rate.
       Reaction(k[19]*t, [A], [B]),                                # A -> B with non constant rate.
       Reaction(k[20]*t*A, [B,C], [D],[2,1],[2])                  # 2A +B -> 2C with non constant rate.
  ]
rs = ReactionSystem(rxs,t,[A,B,C,D],k)
odesys = convert(ODESystem,rs)
sdesys = convert(SDESystem,rs)

# hard coded ODE rhs
function oderhs(u,k,t)
       A = u[1]; B = u[2]; C = u[3]; D = u[4];
       du = zeros(eltype(u),4)
       du[1] = k[1] - k[3]*A + k[4]*C + 2*k[5]*C - k[6]*A*B + k[7]*B^2/2 - k[9]*A*B - k[10]*A^2 - k[11]*A^2/2 - k[12]*A*B^3*C^4/144 - 3*k[13]*A^3*B/6 + 2*k[14] - k[15]*A/(2+A) - k[16] - k[19]*t*A
       du[2] = -k[2]*B + k[4]*C - k[6]*A*B - k[7]*B^2 - k[8]*A*B - k[9]*A*B + k[11]*A^2/2 - 3*k[12]*A*B^3*C^4/144 - k[13]*A^3*B/6 + k[16] + 2*k[18]*B + k[19]*t*A - 2*k[20]*t*A*B^2*C
       du[3] = k[3]*A - k[4]*C - k[5]*C  + k[6]*A*B + k[8]*A*B + k[9]*A*B + k[10]*A^2/2 - 2*k[12]*A*B^3*C^4/144 - 2*k[17]*A*exp(B)*C^2/2 - k[20]*t*A*B^2*C
       du[4] = k[9]*A*B + k[10]*A^2/2 + 3*k[12]*A*B^3*C^4/144 + k[17]*A*exp(B)*C^2/2 + 2*k[20]*t*A*B^2*C
       du
end

# sde noise coefs
function sdenoise(u,k,t)
       A = u[1]; B = u[2]; C = u[3]; D = u[4];
       G = zeros(eltype(u),length(k),length(u))
       z = zero(eltype(u))

       G = [sqrt(k[1]) z  z z;
            z -sqrt(k[2]*B) z z;
            -sqrt(k[3]*A) z sqrt(k[3]*A) z;
            sqrt(k[4]*C) sqrt(k[4]*C) -sqrt(k[4]*C) z;
            2*sqrt(k[5]*C) z -sqrt(k[5]*C) z;
            -sqrt(k[6]*A*B) -sqrt(k[6]*A*B) sqrt(k[6]*A*B) z;
            sqrt(k[7]*B^2/2) -2*sqrt(k[7]*B^2/2) z z;
            z -sqrt(k[8]*A*B) sqrt(k[8]*A*B) z;
            -sqrt(k[9]*A*B) -sqrt(k[9]*A*B) sqrt(k[9]*A*B) sqrt(k[9]*A*B);
            -2*sqrt(k[10]*A^2/2) z sqrt(k[10]*A^2/2) sqrt(k[10]*A^2/2);
            -sqrt(k[11]*A^2/2) sqrt(k[11]*A^2/2) z z;
            -sqrt(k[12]*A*B^3*C^4/144) -3*sqrt(k[12]*A*B^3*C^4/144) -2*sqrt(k[12]*A*B^3*C^4/144) 3*sqrt(k[12]*A*B^3*C^4/144);
            -3*sqrt(k[13]*A^3*B/6) -sqrt(k[13]*A^3*B/6) z z;
            2*sqrt(k[14]) z z z;
            -sqrt(k[15]*A/(2+A)) z z z;
            -sqrt(k[16]) sqrt(k[16]) z z;
            z z -2*sqrt(k[17]*A*exp(B)*C^2/2) sqrt(k[17]*A*exp(B)*C^2/2);
            z 2*sqrt(k[18]*B) z z;
            -sqrt(k[19]*t*A) sqrt(k[19]*t*A) z z;
            z -2*sqrt(k[20]*t*A*B^2*C) -sqrt(k[20]*t*A*B^2*C) +2*sqrt(k[20]*t*A*B^2*C)]'
       return G
end

# test by evaluating drift and diffusion terms
p  = rand(length(k))
u  = rand(length(k))
t  = 0.
du = oderhs(u,p,t)
G  = sdenoise(u,p,t)
sdesys = convert(SDESystem,rs)
sf = SDEFunction{false}(sdesys, states(rs), parameters(rs))
du2 = sf.f(u,p,t)
@test norm(du-du2) < 100*eps()
G2 = sf.g(u,p,t)
@test norm(G-G2) < 100*eps()
