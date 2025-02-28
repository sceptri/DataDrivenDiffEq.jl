# # [Symbolic Regression of Nonlinear Time Continuous Systems](@id symbolic_regression_simple)
# 
# !!! note 
#
#   Symbolic regression is using regularized evolution, simulated annealing, and gradient-free optimization to find suitable equations. 
#   Hence, the performance might differ and depends strongly on the hyperparameters of the optimization. 
#   This example might not recover the groundtruth, but is showing off the use within `DataDrivenDiffEq.jl`.
#
# DataDrivenDiffEq offers an interface to [`SymbolicRegression.jl`](https://github.com/MilesCranmer/SymbolicRegression.jl) to infer more complex functions. To 
# use it, simply load a sufficient version of `SymbolicRegression` (currently we support version >= 0.9).

using DataDrivenDiffEq
using ModelingToolkit
using LinearAlgebra
using OrdinaryDiffEq
using SymbolicRegression
#md using Plots 

A = [-0.9 0.2; 0.0 -0.5]
B = [0.0; 1.0]
u0 = [10.0; -10.0]
tspan = (0.0, 20.0)

f(u,p,t) = A*u .+ B .* sin(0.5*t)

sys = ODEProblem(f, u0, tspan)
sol = solve(sys, Tsit5(), saveat = 0.01);

# We will use the data provided by our problem, but add the control signal `U = sin(0.5*t)` to it. Instead of using a function, like in [another example](@ref linear_continuous_controls)
X = Array(sol) 
t = sol.t 
U = permutedims(sin.(0.5*t))
prob = ContinuousDataDrivenProblem(X, t, U = U)

# And plot the problems data.

#md plot(prob) 

# To solve our problem, we will use [`EQSearch`](@ref), which provides a wrapper for the symbolic regression interface.
# By default, it takes in a `Vector` of `Functions` and additional [keyworded arguments](https://astroautomata.com/SymbolicRegression.jl/v0.6/api/#Options). We will stick to simple operations 
# like subtraction and multiplication, use a `L1DistLoss` , limit the maximum size and punish complex equations while fitting our equations on minibatches. 

alg = EQSearch([-, *], loss = L1DistLoss(), verbosity = 0, maxsize = 9, batching = true, batchSize = 50, parsimony = 0.01f0)

# Again, we `solve` the problem to obtain a [`DataDrivenSolution`](@ref). Note that any additional keyworded arguments are passed onto 
# symbolic regressions [`EquationSearch`](https://astroautomata.com/SymbolicRegression.jl/v0.6/api/#EquationSearch) with the exception of `niterations` which 
# is `max_iter`

res = solve(prob, alg, max_iter = 1_0, numprocs = 0, multithreading = false)
#md println(res) 

# We see that the system has been recovered correctly, indicated by the small error. A closer look at the equations r

system = result(res)
#md 
println(system)
println(res)
# Shows that while not obvious, the representation 
# And also plot the prediction of the recovered dynamics

#md plot(res) 

# To convert the result into an `ODESystem`, we substitute the control signal

u = controls(system)
t = get_iv(system)

subs_control = (u[1] => sin(0.5*t))

eqs = map(equations(system)) do eq
    eq.lhs ~ substitute(eq.rhs, subs_control)
end

@named sys = ODESystem(
    eqs, 
    get_iv(system),
    states(system),
    []
    );

# And simulated using `OrdinaryDiffEq.jl` using the (known) initial conditions and the parameter mapping of the estimation.
# Since the parameters are *hard numerical values* we do not need to include those.

x = states(system)
x0 = [x[1] => u0[1], x[2] => u0[2]]

ode_prob = ODEProblem(sys, x0, tspan)
estimate = solve(ode_prob, Tsit5(), saveat = prob.t);

# And look at the result
#md plot(sol, color = :black)
#md plot!(estimate, color = :red, linestyle = :dash)

#md # ## [Copy-Pasteable Code](@id symbolic_regression_simple_copy_paste)
#md #
#md # ```julia
#md # @__CODE__
#md # ```

@test all(l2error(res) .<= 5e-1) #src
@test Array(sol) ≈ Array(estimate) rtol = 5e-2 #src
