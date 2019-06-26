defmodule MiataBot.Discord do
  alias MiataBot.{
    Repo,
    Carinfo,
    LookingForMiataTimer
  }

  import MiataBot.Discord.Util

  require Logger

  use Nostrum.Consumer
  alias Nostrum.Api
  alias Nostrum.Struct.Embed

  # @miata_discord_guild_id 322_080_266_761_797_633
  @verification_channel_id 322_127_502_212_333_570
  @looking_for_miata_role_id 504_088_951_485_890_561
  # @miata_fan_role_id 439_493_557_301_280_789
  Module.register_attribute(__MODULE__, :bangs, accumulate: true)

  def start_link do
    Consumer.start_link(__MODULE__, name: __MODULE__)
  end

  # uncomment to own Mark Sticken
  # def handle_event({:MESSAGE_CREATE, {%{author: %{id: 362309360124428299}, channel_id: channel_id} = message}, _state}) do
  #   Api.create_message(channel_id, "<@!362309360124428299> https://media.discordapp.net/attachments/322162421156282369/581557012593246209/13t5kz.jpg")
  #   Api.delete_message(message)
  # end

  # def handle_event({:MESSAGE_CREATE, {%{author: author = %{id: id}, channel_id: channel_id} = message}, _state}) do
  #   IO.inspect(author, label: "AUTHOR")
  # end

  bang "ya rip", "https://www.youtube.com/watch?v=fKLmZNnMT0A"
  bang "!rotaryroast", "https://www.stancenation.com/wp-content/uploads/2012/04/1211.jpg"

  bang "!monstertruck",
       "https://cdn.discordapp.com/attachments/500143495043088395/590656753583259658/20190610_170551_HDR.jpg"

  bang "!hercroast",
       "https://cdn.discordapp.com/attachments/500143495043088395/590654628115382277/032216_Fire_Car_AB.jpg"

  bang "!longintake",
       "https://cdn.discordapp.com/attachments/384483113985900544/592810948201545739/IMG_20190613_153900.jpg"

  bang "!18swapintake",
       "https://media.discordapp.net/attachments/322080529245798401/593511885664550921/IMG_1140.jpg"

  bang "!torquespecs",
       "https://www.miata.net/garage/torque.html"

  def handle_event({:MESSAGE_CREATE, {%{content: "$" <> command} = message}, _state}) do
    handle_command(command, message)
  end

  def handle_event({:MESSAGE_CREATE, {%{channel_id: @verification_channel_id} = message}, _state}) do
    case message.attachments do
      [%{url: url} | _rest] ->
        year = extract_year(message.content)
        params = %{image_url: url, discord_user_id: message.author.id, year: year}
        do_update(@verification_channel_id, message.author, params)

      _ ->
        :noop
    end
  end

  def handle_event({:GUILD_AVAILABLE, {data}, _ws_state}) do
    # IO.inspect(data, label: "GUILD_AVAILABLE")
    for {_member_id, m} <- data.members do
      if @looking_for_miata_role_id in m.roles do
        ensure_looking_for_miata_timer(m)
      end
    end
  end

  def handle_event({:GUILD_MEMBER_UPDATE, {_member_id, old, new}, _ws_state}) do
    if @looking_for_miata_role_id in (new.roles -- old.roles) do
      Logger.info("refreshing timer for #{new.user.username}")
      timer = ensure_looking_for_miata_timer(new)
      refresh_looking_for_miata_timer(timer)
    end

    if @looking_for_miata_role_id in (old.roles -- new.roles) do
      Logger.info("refreshing timer for #{new.user.username}")
      timer = ensure_looking_for_miata_timer(new)
      Repo.delete!(timer)
    end
  end

  # dyno
  def handle_event(
        {:MESSAGE_CREATE, {%{author: %{id: 155_149_108_183_695_360}} = message}, _state}
      ) do
    IO.inspect(message, label: "DYNO")
  end

  def handle_event(event) do
    _ = inspect(event)
    # IO.inspect(event, label: "UNHANDLED EVENT")
    :noop
  end

  defp ensure_looking_for_miata_timer(member) do
    case Repo.get_by(LookingForMiataTimer, discord_user_id: member.user.id) do
      nil ->
        LookingForMiataTimer.changeset(%LookingForMiataTimer{}, %{
          joined_at: member.joined_at,
          discord_user_id: member.user.id
        })
        |> Repo.insert!()

      timer ->
        timer
    end
  end

  def refresh_looking_for_miata_timer(timer) do
    LookingForMiataTimer.changeset(timer, %{
      refreshed_at: DateTime.utc_now()
    })
    |> Repo.update!()
  end

  def handle_command("bangs", %{channel_id: channel_id}) do
    msg = Enum.join(@bangs, "\n")
    Api.create_message!(channel_id, "Available bangs: #{msg}")
  end

  def handle_command("help", %{channel_id: channel_id}) do
    embed =
      %Embed{}
      |> Embed.put_title("Available commands")
      |> Embed.put_field("carinfo", """
      Shows the author's carinfo
      """)
      |> Embed.put_field("carinfo get <user>", """
      Shows a users carinfo
      """)
      |> Embed.put_field("carinfo update title", """
      Sets the author's carinfo title
      """)
      |> Embed.put_field("carinfo update image", """
      Updates the author's carinfo from an attached photo
      """)
      |> Embed.put_field("carinfo update year <year>", """
      Sets the author's carinfo year
      """)
      |> Embed.put_field("carinfo update color code <color>", """
      Sets the author's carinfo color code
      """)

    Api.create_message(channel_id, embed: embed)
  end

  def handle_command("carinfo", %{channel_id: channel_id, author: author}) do
    embed = carinfo(author)
    Api.create_message(channel_id, embed: embed)
  end

  def handle_command("carinfo get" <> user, %{channel_id: channel_id}) do
    case get_user(user) do
      {:ok, user} ->
        embed = carinfo(user)
        Api.create_message(channel_id, embed: embed)

      {:error, _} ->
        Api.create_message(channel_id, "Could not find user: #{user}")
    end
  end

  def handle_command("carinfo update image" <> _, %{
        channel_id: channel_id,
        author: author,
        attachments: [attachment | _]
      }) do
    params = %{image_url: attachment.url, discord_user_id: author.id}
    do_update(channel_id, author, params)
  end

  def handle_command("carinfo update year " <> year, %{
        channel_id: channel_id,
        author: author
      }) do
    params = %{year: year, discord_user_id: author.id}
    do_update(channel_id, author, params)
  end

  def handle_command("carinfo update color code " <> color_code, %{
        channel_id: channel_id,
        author: author
      }) do
    params = %{color_code: color_code, discord_user_id: author.id}
    do_update(channel_id, author, params)
  end

  def handle_command("carinfo update title " <> title, %{
        channel_id: channel_id,
        author: author
      }) do
    params = %{title: title, discord_user_id: author.id}
    do_update(channel_id, author, params)
  end

  def handle_command(_command, message) do
    IO.inspect(message, label: "unhandled command")
  end

  def do_update(channel_id, author, params) do
    info = Repo.get_by(Carinfo, discord_user_id: author.id) || %Carinfo{}
    changeset = Carinfo.changeset(info, params)

    embed =
      case Repo.insert_or_update(changeset) do
        {:ok, _} ->
          carinfo(author)

        {:error, changeset} ->
          changeset_to_error_embed(changeset)
      end

    Api.create_message(channel_id, embed: embed)
  end

  def changeset_to_error_embed(changeset) do
    embed = Embed.put_title(%Embed{}, "Error performing action #{changeset.action}")

    Enum.reduce(changeset.errors, embed, fn {key, {msg, _opts}}, embed ->
      Embed.put_field(embed, to_string(key), msg)
    end)
  end

  def carinfo(author) do
    case Repo.get_by(Carinfo, discord_user_id: author.id) do
      nil ->
        %Embed{}
        |> Embed.put_title("#{author.username}'s Miata")
        |> Embed.put_description("#{author.username} has not registered a vehicle.")

      %Carinfo{} = info ->
        %Embed{}
        |> Embed.put_title(info.title || "#{author.username}'s Miata")
        |> Embed.put_color(info.color || 0xD11A06)
        |> Embed.put_field("Year", info.year || "unknown year")
        |> Embed.put_field("Color Code", info.color_code || "unknown color code")
        |> Embed.put_image(info.image_url)
    end
  end

  defp extract_year(_), do: nil

  defp get_user("<@!" <> almost_snowflake) do
    snowflake = String.trim_trailing(almost_snowflake, ">")
    get_user(snowflake)
  end

  defp get_user(user) do
    case Nostrum.Snowflake.cast(user) do
      {:ok, snowflake} ->
        Api.get_user(snowflake)

      _ ->
        {:error, "unknown user"}
    end
  end
end
