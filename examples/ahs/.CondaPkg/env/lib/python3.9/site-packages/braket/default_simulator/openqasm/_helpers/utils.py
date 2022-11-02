from functools import singledispatch, update_wrapper


def singledispatchmethod(func):
    """Implement singledispatchmethod for Python 3.7"""
    dispatcher = singledispatch(func)

    def wrapper(*args, **kw):
        return dispatcher.dispatch(args[1].__class__)(*args, **kw)

    wrapper.register = dispatcher.register
    update_wrapper(wrapper, func)
    return wrapper
