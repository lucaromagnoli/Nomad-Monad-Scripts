from contextlib import contextmanager
import helpers as hlp
import reapy
import reapy.reascript_api as RPR


def reset_fades(item: 'reapy.Item'):
    item.set_info_value('D_FADEINLEN_AUTO', 0)
    item.set_info_value('D_FADEOUTLEN_AUTO', 0)


@reapy.inside_reaper()
def main():
    project = reapy.Project(0)
    if not project.selected_items:
        reapy.show_message_box(title='No item selected',
                               text='Please select an item')
    for item in project.selected_items:
        rsmpl_track = hlp.get_resample_track_by_source_track(project, item.track)
        if rsmpl_track is None:
            reapy.show_message_box(title=item.track.name, text='No Resample Track associated to Track')
        else:
            with hlp.undo_context(project):
                project.perform_action(40209)   # render item
                project.perform_action(40698)  # copy item
                project.cursor_position = item.position
                project.perform_action(42398)  # paste item
                sel_item = project.get_selected_item(0)
                sel_item.track = rsmpl_track
                reset_fades(item)
                reset_fades(sel_item)
                item.track.select()
                for take in item.takes:
                    if take.is_midi:
                        take.make_active_take()
                        project.perform_action(40131)   # crop to active take
                        break
                # sel_item.track.select()
                # for take in sel_item.takes:
                #     if not take.is_midi:
                #         take.make_active_take()
                #         project.perform_action(40131)  # # crop to active take
                #         break





if __name__ == '__main__':
    with reapy.inside_reaper():
        main()
