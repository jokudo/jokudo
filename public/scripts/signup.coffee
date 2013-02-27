jQuery ->
  console.log 'yay'
  ($ "#submit-signup-form").click (e) ->
    console.log 'here'
    $email = $ '#email'
    $errors = $ '#errors'
    email = $email.val()
    if not email.match /^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.edu$/i
      return $errors.hide().html('Please enter a valid .edu email').fadeIn()
    $.ajax
      url: '/signup'
      type: 'post'
      data:
        email: email
      success: (res) ->
        if res.error
          return $errors.hide().html(res.error).fadeIn()
        else
          window.location = '/thank-you'
      error: (e) ->
        return $errors.hide().html('Something went wrong, please try again in a second').fadeIn()
